require 'json'
require 'sinatra/base'
require 'erubi'
require 'mysql2'
require 'mysql2-cs-bind'
require 'sinatra/activerecord'

module Torb
  class ApplicationController < Sinatra::Base
    configure :development do
      require 'sinatra/reloader'
      register Sinatra::Reloader
    end

    set :root, File.expand_path('../..', __dir__)
    set :sessions, key: 'torb_session', expire_after: 3600
    set :session_secret, 'tagomoris'
    set :protection, frame_options: :deny

    register Sinatra::ActiveRecordExtension
    set :database,
        adapter: 'mysql2',
        database: ENV['DB_DATABASE'],
        username: ENV['DB_USER'],
        password: ENV['DB_PASS'],
        host: ENV['DB_HOST']

    set :erb, escape_html: true

    set :login_required,
        lambda { |value|
          condition do
            halt_with_error 401, 'login_required' if value && !get_login_user
          end
        }

    set :admin_login_required,
        lambda { |value|
          condition do
            if value && !get_login_administrator
              halt_with_error 401, 'admin_login_required'
            end
          end
        }

    before '/api/*|/admin/api/*' do
      content_type :json
    end

    helpers do
      def db
        Thread.current[:db] ||= Mysql2::Client.new(
          host: ENV['DB_HOST'],
          port: ENV['DB_PORT'],
          username: ENV['DB_USER'],
          password: ENV['DB_PASS'],
          database: ENV['DB_DATABASE'],
          database_timezone: :utc,
          cast_booleans: true,
          reconnect: true,
          init_command: 'SET SESSION sql_mode="STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"',
        )
      end

      def get_events(where = nil)
        where ||= ->(e) { e['public_fg'] }

        # db.query('BEGIN')
        # begin
        #   event_ids = db.query('SELECT * FROM events ORDER BY id ASC').select(&where).map { |e| e['id'] }
        #   events =
        #     event_ids.map do |event_id|
        #       event = get_event(event_id)
        #       event['sheets'].each { |sheet| sheet.delete('detail') }
        #       event
        #     end
        #   db.query('COMMIT')
        # rescue StandardError
        #   db.query('ROLLBACK')
        # end

        # events
        # TODO: WIP
        Event.where.not(id: nil).order(id: 'ASC').map(&:attributes)
      end

      def get_event(event_id, login_user_id = nil)
        event = db.xquery('SELECT * FROM events WHERE id = ?', event_id).first
        return unless event

        # zero fill
        event['total']   = 0
        event['remains'] = 0
        event['sheets'] = {}
        ['S', 'A', 'B', 'C'].each do |rank|
          event['sheets'][rank] = { 'total' => 0, 'remains' => 0, 'detail' => [] }
        end

        sheets = db.query('SELECT * FROM sheets ORDER BY `rank`, num')
        sheets.each do |sheet|
          event['sheets'][sheet['rank']]['price'] ||= event['price'] + sheet['price']
          event['total'] += 1
          event['sheets'][sheet['rank']]['total'] += 1

          reservation = db.xquery('SELECT * FROM reservations WHERE event_id = ? AND sheet_id = ? AND canceled_at IS NULL GROUP BY event_id, sheet_id HAVING reserved_at = MIN(reserved_at)', event['id'], sheet['id']).first
          if reservation
            sheet['mine']        = true if login_user_id && reservation['user_id'] == login_user_id
            sheet['reserved']    = true
            sheet['reserved_at'] = reservation['reserved_at'].to_i
          else
            event['remains'] += 1
            event['sheets'][sheet['rank']]['remains'] += 1
          end

          event['sheets'][sheet['rank']]['detail'].push(sheet)

          sheet.delete('id')
          sheet.delete('price')
          sheet.delete('rank')
        end

        event['public'] = event.delete('public_fg')
        event['closed'] = event.delete('closed_fg')

        event
      end

      def sanitize_event(event)
        sanitized = event.dup # shallow clone
        sanitized.delete('price')
        sanitized.delete('public')
        sanitized.delete('closed')
        sanitized
      end

      def get_login_user
        user_id = session[:user_id]
        return unless user_id

        # db.xquery('SELECT id, nickname FROM users WHERE id = ?', user_id).first
        User.find(user_id).attributes
      end

      def get_login_administrator
        administrator_id = session['administrator_id']
        return unless administrator_id

        db.xquery('SELECT id, nickname FROM administrators WHERE id = ?', administrator_id).first
      end

      def validate_rank(rank)
        db.xquery('SELECT COUNT(*) AS total_sheets FROM sheets WHERE `rank` = ?', rank).first['total_sheets'] > 0
      end

      def body_params
        @body_params ||= JSON.parse(request.body.tap(&:rewind).read)
      end

      def halt_with_error(status = 500, error = 'unknown')
        halt status, { error: error }.to_json
      end

      def render_report_csv(reports)
        reports = reports.sort_by { |report| report[:sold_at] }

        keys = [:reservation_id, :event_id, :rank, :num, :price, :user_id, :sold_at, :canceled_at]
        body = keys.join(',')
        body << "\n"
        reports.each do |report|
          body << report.values_at(*keys).join(',')
          body << "\n"
        end

        headers(
          'Content-Type' => 'text/csv; charset=UTF-8',
          'Content-Disposition' => 'attachment; filename="report.csv"',
        )
        body
      end
    end

    get '/' do
      @user   = get_login_user
      @events = get_events.map(&method(:sanitize_event))
      erb :index
    end

    get '/initialize' do
      system '../../db/init.sh'

      status 204
    end
  end
end

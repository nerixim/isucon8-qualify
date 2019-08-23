module Torb
  class UsersController < ApplicationController
    post '/api/users' do
      nickname   = body_params['nickname']
      login_name = body_params['login_name']
      password   = body_params['password']

      db.query('BEGIN')
      begin
        duplicated = db.xquery('SELECT * FROM users WHERE login_name = ?', login_name).first
        if duplicated
          db.query('ROLLBACK')
          halt_with_error 409, 'duplicated'
        end

        db.xquery('INSERT INTO users (login_name, pass_hash, nickname) VALUES (?, SHA2(?, 256), ?)', login_name, password, nickname)
        user_id = db.last_id
        db.query('COMMIT')
      rescue StandardError => e
        warn "rollback by: #{e}"
        db.query('ROLLBACK')
        halt_with_error
      end

      status 201
      { id: user_id, nickname: nickname }.to_json
    end

    get '/api/users/:id', login_required: true do |user_id|
      user = db.xquery('SELECT id, nickname FROM users WHERE id = ?', user_id).first
      halt_with_error 403, 'forbidden' if user['id'] != get_login_user['id']

      rows = db.xquery('SELECT r.*, s.rank AS sheet_rank, s.num AS sheet_num FROM reservations r INNER JOIN sheets s ON s.id = r.sheet_id WHERE r.user_id = ? ORDER BY IFNULL(r.canceled_at, r.reserved_at) DESC LIMIT 5', user['id'])
      recent_reservations =
        rows.map do |row|
          event = get_event(row['event_id'])
          price = event['sheets'][row['sheet_rank']]['price']
          event.delete('sheets')
          event.delete('total')
          event.delete('remains')

          {
            id: row['id'],
            event: event,
            sheet_rank: row['sheet_rank'],
            sheet_num: row['sheet_num'],
            price: price,
            reserved_at: row['reserved_at'].to_i,
            canceled_at: row['canceled_at']&.to_i,
          }
        end

      user['recent_reservations'] = recent_reservations
      user['total_price'] = db.xquery('SELECT IFNULL(SUM(e.price + s.price), 0) AS total_price FROM reservations r INNER JOIN sheets s ON s.id = r.sheet_id INNER JOIN events e ON e.id = r.event_id WHERE r.user_id = ? AND r.canceled_at IS NULL', user['id']).first['total_price']

      rows = db.xquery('SELECT event_id FROM reservations WHERE user_id = ? GROUP BY event_id ORDER BY MAX(IFNULL(canceled_at, reserved_at)) DESC LIMIT 5', user['id'])
      recent_events =
        rows.map do |row|
          event = get_event(row['event_id'])
          event['sheets'].each { |_, sheet| sheet.delete('detail') }
          event
        end
      user['recent_events'] = recent_events

      user.to_json
    end
  end
end

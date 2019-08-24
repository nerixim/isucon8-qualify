# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do

  create_table "administrators", id: :integer, unsigned: true, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", force: :cascade do |t|
    t.string "nickname", limit: 128, null: false
    t.string "login_name", limit: 128, null: false
    t.string "pass_hash", limit: 128, null: false
    t.index ["login_name"], name: "login_name_uniq", unique: true
  end

  create_table "events", id: :integer, unsigned: true, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", force: :cascade do |t|
    t.string "title", limit: 128, null: false
    t.boolean "public_fg", null: false
    t.boolean "closed_fg", null: false
    t.integer "price", null: false, unsigned: true
  end

  create_table "reservations", id: :integer, unsigned: true, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", force: :cascade do |t|
    t.integer "event_id", null: false, unsigned: true
    t.integer "sheet_id", null: false, unsigned: true
    t.integer "user_id", null: false, unsigned: true
    t.datetime "reserved_at", precision: 6, null: false
    t.datetime "canceled_at", precision: 6
    t.index ["event_id", "sheet_id"], name: "event_id_and_sheet_id_idx"
  end

  create_table "sheets", id: :integer, unsigned: true, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", force: :cascade do |t|
    t.string "rank", limit: 128, null: false
    t.integer "num", null: false, unsigned: true
    t.integer "price", null: false, unsigned: true
    t.index ["rank", "num"], name: "rank_num_uniq", unique: true
  end

  create_table "users", id: :integer, unsigned: true, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", force: :cascade do |t|
    t.string "nickname", limit: 128, null: false
    t.string "login_name", limit: 128, null: false
    t.string "pass_hash", limit: 128, null: false
    t.index ["login_name"], name: "login_name_uniq", unique: true
  end

end

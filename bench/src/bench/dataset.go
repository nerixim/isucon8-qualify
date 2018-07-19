package bench

import (
	"bufio"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

var (
	DataPath = "./data"
	DataSet  BenchDataSet
)

func reverse(s string) string {
	r := []rune(s)
	for i, j := 0, len(r)-1; i < len(r)/2; i, j = i+1, j-1 {
		r[i], r[j] = r[j], r[i]
	}
	return string(r)
}

func prepareUserDataSet() {
	file, err := os.Open(filepath.Join(DataPath, "user.tsv"))
	must(err)
	defer file.Close()

	s := bufio.NewScanner(file)
	for i := 0; s.Scan(); i++ {
		line := strings.Split(s.Text(), "\t")
		nickname := line[0]
		addr := line[1]
		loginName := strings.Split(addr, "@")[0]

		user := &AppUser{
			LoginName: loginName,
			Password:  loginName + reverse(loginName),
			Nickname:  nickname,
		}

		if i < 1000 {
			DataSet.Users = append(DataSet.Users, user)
		} else {
			DataSet.NewUsers = append(DataSet.NewUsers, user)
		}
	}
}

func prepareAdministratorDataSet() {
	administrator := &Administrator{
		LoginName: "admin",
		Password:  "admin",
		Nickname:  "admin",
	}

	DataSet.Administrators = append(DataSet.Administrators, administrator)
}

func prepareEventDataSet() {
	file, err := os.Open(filepath.Join(DataPath, "event.tsv"))
	must(err)
	defer file.Close()

	s := bufio.NewScanner(file)
	next_id := uint(1)
	for i := 0; s.Scan(); i++ {
		line := strings.Split(s.Text(), "\t")
		title := line[0]
		public_fg, _ := strconv.ParseBool(line[1])
		price, _ := strconv.Atoi(line[2])

		event := &Event{
			ID:       next_id,
			Title:    title,
			PublicFg: public_fg,
			Price:    uint(price),
		}
		next_id++

		DataSet.Events = append(DataSet.Events, event)
	}

	for i := 0; i < 10; i++ {
		event := &Event{
			ID:       next_id,
			Title:    fmt.Sprintf("イベント%d", i+1),
			PublicFg: true,
			Price:    uint(i * 1000),
		}
		next_id++
		DataSet.NewEvents = append(DataSet.NewEvents, event)
	}
}

func PrepareDataSet() {
	log.Println("datapath", DataPath)
	prepareUserDataSet()
	prepareAdministratorDataSet()
	prepareEventDataSet()
}

func fbadf(w io.Writer, f string, params ...interface{}) {
	for i, param := range params {
		switch v := param.(type) {
		case []byte:
			params[i] = fmt.Sprintf("_binary x'%s'", hex.EncodeToString(v))
		case *time.Time:
			params[i] = strconv.Quote(v.Format("2006-01-02 15:04:05"))
		case time.Time:
			params[i] = strconv.Quote(v.Format("2006-01-02 15:04:05"))
		case bool:
			if v {
				params[i] = strconv.Quote("1")
			} else {
				params[i] = strconv.Quote("0")
			}
		default:
			params[i] = strconv.Quote(fmt.Sprint(v))
		}
	}
	fmt.Fprintf(w, f, params...)
}

func GenerateInitialDataSetSQL(outputPath string) {
	outFile, err := os.Create(outputPath)
	must(err)
	defer outFile.Close()

	w := gzip.NewWriter(outFile)
	defer w.Close()

	fbadf(w, "SET NAMES utf8mb4;")
	fbadf(w, "BEGIN;")

	// user
	for i, user := range DataSet.Users {
		passDigest := fmt.Sprintf("%x", sha256.Sum256([]byte(user.Password)))
		must(err)
		fbadf(w, "INSERT INTO users (id, nickname, login_name, pass_hash) VALUES (%s, %s, %s, %s);",
			i+1, user.Nickname, user.LoginName, passDigest)
	}

	// administrator
	for i, administrator := range DataSet.Administrators {
		passDigest := fmt.Sprintf("%x", sha256.Sum256([]byte(administrator.Password)))
		must(err)
		fbadf(w, "INSERT INTO administrators (id, nickname, login_name, pass_hash) VALUES (%s, %s, %s, %s);",
			i+1, administrator.Nickname, administrator.LoginName, passDigest)
	}

	// event
	for _, event := range DataSet.Events {
		must(err)
		fbadf(w, "INSERT INTO events (id, title, public_fg, price) VALUES (%s, %s, %s, %s);",
			event.ID, event.Title, event.PublicFg, event.Price)
	}

	fbadf(w, "COMMIT;")
}

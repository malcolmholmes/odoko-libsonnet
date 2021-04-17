package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/go-sql-driver/mysql"
	"github.com/ziutek/mymysql/godrv"
)

func initialiseDatabase(dbHost, dbRootPass, dbName, dbUser, dbPass string) error {
	createSQL := fmt.Sprintf("CREATE DATABASE IF NOT EXISTS `%s`;", dbName)
	grantSQL := fmt.Sprintf("GRANT ALL ON `%s`.* TO `%s`@`%%` IDENTIFIED BY '%s';", dbName, dbUser, dbPass)
	godrv.Register("SET NAMES utf8")
	connStr := fmt.Sprintf("root:%s@tcp(%s:%d)/", dbRootPass, dbHost, 3306)
	db, err := sql.Open("mysql", connStr)
	_, err = db.Exec(createSQL)
	if err != nil {
		return err
	}
	_, err = db.Exec(grantSQL)
	if err != nil {
		return err
	}
	log.Printf("Created database %s", dbName)
	return nil
}

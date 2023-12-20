package main

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"

	geoip2 "github.com/oschwald/geoip2-golang"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/ua-parser/uap-go/uaparser"
)

var (
	parser *uaparser.Parser
	db     *geoip2.Reader
)

func SetupAnalytics() error {
	if os.Getenv("DISABLE_ANALYTICS") == "true" {
		return nil
	}
	var err error
	parser, err = uaparser.New("/regexes.yaml")
	if err != nil {
		return err
	}
	db, err = geoip2.Open("/GeoLite2-City.mmdb")
	if err != nil {
		return err
	}
	http.HandleFunc("/active/track", HandleAnalytics)
	http.Handle("/active/metrics", promhttp.Handler())

	return nil
}
func HandleAnalytics(w http.ResponseWriter, req *http.Request) {
	client := getUserAgent(req)
	ip := getIP(req)
	record, err := db.City(ip)
	if err != nil {
		HandleResponse(w, err, "Error handling analytics", 500)
	}
	logline := map[string]string{}
	add := func(name, value string) {
		logline[name] = value
	}
	add("browser", client.UserAgent.Family)
	add("operating_system", client.Os.Family)
	add("platform", client.Device.Family)
	add("country", record.Country.IsoCode)
	add("url", req.URL.Path)
	if referer, ok := req.Header["Referer"]; ok {
		add("referer", referer[0])
	}
	b, err := json.Marshal(logline)
	if err != nil {
		fmt.Println("error:", err)
	}
	fmt.Println(string(b))
	/*
		fmt.Println("USER AGENT", req.UserAgent())
		fmt.Println("UA Family", client.UserAgent.Family)  // "Amazon Silk"
		fmt.Println("UA Major", client.UserAgent.Major)    // "1"
		fmt.Println("UA Minor", client.UserAgent.Minor)    // "1"
		fmt.Println("UA Patch", client.UserAgent.Patch)    // "0-80"
		fmt.Println("OS Family", client.Os.Family)         // "Android"
		fmt.Println("OS Major", client.Os.Major)           // ""
		fmt.Println("OS Minor", client.Os.Minor)           // ""
		fmt.Println("OS Patch", client.Os.Patch)           // ""
		fmt.Println("OS PatchMinor", client.Os.PatchMinor) // ""
		fmt.Println("Device Family", client.Device.Family) // "Kindle Fire"
		log.Println("REQUEST HOST", req.Host)
		log.Println("REQUEST URL", req.URL)
		log.Println("REQUEST IP", ip.String())
		fmt.Printf("Portuguese (BR) city name: %v\n", record.City.Names["pt-BR"])
		if len(record.Subdivisions) > 0 {
			fmt.Printf("English subdivision name: %v\n", record.Subdivisions[0].Names["en"])
		}
		fmt.Printf("Russian country name: %v\n", record.Country.Names["ru"])
		fmt.Printf("ISO country code: %v\n", record.Country.IsoCode)
		fmt.Printf("Time zone: %v\n", record.Location.TimeZone)
		fmt.Printf("Coordinates: %v, %v\n", record.Location.Latitude, record.Location.Longitude)
	*/
	w.WriteHeader(204)
}

func getUserAgent(req *http.Request) *uaparser.Client {
	uaString := req.UserAgent()
	client := parser.Parse(uaString)
	return client
}

// GetIP gets a requests IP address by reading off the forwarded-for
// header (for proxies) and falls back to use the remote address.
func getIP(r *http.Request) net.IP {
	forwarded := r.Header.Get("X-FORWARDED-FOR")
	if forwarded != "" {
		return net.ParseIP(forwarded)
	}
	forwarded = r.Header.Get("X-Forwarded-For")
	if forwarded != "" {
		return net.ParseIP(forwarded)
	}
	return net.ParseIP(r.RemoteAddr)
}

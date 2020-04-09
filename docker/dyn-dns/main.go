package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"google.golang.org/api/dns/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

var (
	ingressCount = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "dyndns_ingress_count",
		Help: "The number ingresses found",
	})
	domainCount = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "dyndns_domain_count",
		Help: "The number of tracked domains",
	})
	domainsChecked = promauto.NewCounter(prometheus.CounterOpts{
		Name: "dyndns_domains_checked_total",
		Help: "The total number of domains checked",
	})
	domainsUpdated = promauto.NewCounter(prometheus.CounterOpts{
		Name: "dyndns_domains_updated_total",
		Help: "The total number of domains updated",
	})
)

func main() {

	googleProject := os.Getenv("GOOGLE_PROJECT")
	clientset := getK8sClientSet()
	ctx := context.Background()
	dnsService, err := dns.NewService(ctx)

	go func() {
		http.Handle("/metrics", promhttp.Handler())
		http.ListenAndServe(":8080", nil)
	}()

	if err != nil {
		panic(err.Error())
	}
	for {
		_, err := loop(googleProject, clientset, dnsService)
		if err != nil {
			log.Println("Error:", err.Error())
		}
		log.Println("Checks completed")
		time.Sleep(60 * time.Second)
	}
}

func loop(googleProject string, clientset *kubernetes.Clientset, dnsService *dns.Service) (bool, error) {
	domains, err := getDomains(*clientset)
	if err != nil {
		return false, err
	}
	myIP, err := lookupMyIP()
	if err != nil {
		return false, err
	}
	changesMade := false
	for _, domain := range domains {
		ip, err := lookupIPViaGoogle(googleProject, dnsService, domain)
		if err != nil {
			return false, err
		}
		domain.IP = ip
		log.Printf("Checking %s: %s <-> %s", domain.Name, domain.IP, myIP)
		domainsChecked.Inc()
		if domain.IP != myIP {
			err = updateDNS(googleProject, dnsService, domain, myIP)
			if err != nil {
				return false, err
			}
			domainsUpdated.Inc()
			changesMade = true
		}
	}
	return changesMade, nil
}

func getK8sClientSet() *kubernetes.Clientset {

	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}
	return clientset
}

// Domain describes everything required to update a domain
type Domain struct {
	Zone string
	Name string
	IP   string
}

func getDomains(clientset kubernetes.Clientset) ([]Domain, error) {
	ingresses, err := clientset.ExtensionsV1beta1().Ingresses("").List(metav1.ListOptions{})
	if err != nil {
		panic(err.Error())
	}
	log.Printf("%d ingresses found in the cluster", len(ingresses.Items))
	ingressCount.Set(float64(len(ingresses.Items)))

	domains := []Domain{}

	for _, ingress := range ingresses.Items {
		var zone string
		for k, v := range ingress.Annotations {
			if k == "odoko.com/dyn-dns-zone" {
				zone = v
				break
			}
		}
		if zone == "" {
			continue
		}

		for _, rule := range ingress.Spec.Rules {
			domains = append(domains, Domain{zone, rule.Host, ""})
		}
	}
	log.Printf("%d domains with matching annotation odoko.com/dyn-dns-zone", len(domains))
	domainCount.Set(float64(len(domains)))
	return domains, nil
}

func lookupMyIP() (string, error) {
	resp, err := http.Get("http://ipecho.net/plain")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	return string(body), err
}

func lookupIPViaGoogle(googleProject string, dnsService *dns.Service, domain Domain) (string, error) {
	recordSets, err := dnsService.ResourceRecordSets.List(googleProject, domain.Zone).Do()
	if err != nil {
		return "", err
	}
	dottedDomain := domain.Name + "."
	for _, recordSet := range recordSets.Rrsets {
		if recordSet.Name == dottedDomain {
			if len(recordSet.Rrdatas) == 0 {
				return "", fmt.Errorf("Domain %s did not return an IP", domain.Name)
			} else if len(recordSet.Rrdatas) > 1 {
				return "", fmt.Errorf("Domain %s multiple IPs. This is not supported", domain.Name)
			}
			return recordSet.Rrdatas[0], nil
		}
	}
	return "", fmt.Errorf("Domain %s not found", domain.Name)
}

func lookupIPViaDNS(domain Domain) (string, error) {
	ips, err := net.LookupIP(domain.Name)
	if err != nil {
		return "", err
	}
	if len(ips) == 0 {
		return "", fmt.Errorf("%s did not resolve to an IP", domain.Name)
	} else if len(ips) > 1 {
		return "", fmt.Errorf("%s resolves to multiple IPs. This is not supported", domain.Name)
	}
	ip := ips[0]

	return ip.String(), nil
}

func updateDNS(googleProject string, dnsService *dns.Service, domain Domain, myIP string) error {
	log.Printf("Updating %s", domain.Name)

	change := &dns.Change{}
	deletion := dns.ResourceRecordSet{
		Name:    domain.Name + ".",
		Rrdatas: []string{domain.IP},
		Ttl:     60,
		Type:    "A",
	}
	addition := dns.ResourceRecordSet{
		Name:    domain.Name + ".",
		Rrdatas: []string{myIP},
		Ttl:     60,
		Type:    "A",
	}

	change.Additions = append(change.Additions, &addition)
	change.Deletions = append(change.Deletions, &deletion)

	_, err := dnsService.Changes.Create(googleProject, domain.Zone, change).Do()
	if err != nil {
		return err
	}
	log.Printf("Update complete for %s", domain.Name)

	return nil
}

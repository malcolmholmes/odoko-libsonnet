package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"
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
	domainsChecked = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dyndns_domains_checked_total",
			Help: "The total number of domains checked",
		},
		[]string{"domain"},
	)
	domainsUpdated = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dyndns_domains_updated_total",
			Help: "The total number of domains updated",
		},
		[]string{"domain"},
	)
	errorsOccurred = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dyndns_error_total",
			Help: "The total number of errors",
		},
		[]string{"type", "domain"},
	)
	apiCalls = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dyndns_google_api_call_total",
			Help: "The total number of calls to the Google API",
		},
		[]string{"type", "domain"},
	)
	apiCallErrors = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dyndns_google_api_call_error_total",
			Help: "The total number of failed calls to the Google API",
		},
		[]string{"type", "domain"},
	)
)

// Domain describes everything required to update a domain
type Domain struct {
	Zone string
	Name string
	IP   string
}

func ifErrorPanic(err error) {
	if err != nil {
		panic(err.Error())
	}
}

type serviceSet struct {
	k8s           *kubernetes.Clientset
	dns           *dns.Service
	googleProject string
}

func getServiceSet() serviceSet {
	serviceSet := serviceSet{}

	config, err := rest.InClusterConfig()
	ifErrorPanic(err)
	clientset, err := kubernetes.NewForConfig(config)
	ifErrorPanic(err)
	serviceSet.k8s = clientset

	ctx := context.Background()
	dnsService, err := dns.NewService(ctx)
	ifErrorPanic(err)
	serviceSet.dns = dnsService

	serviceSet.googleProject = os.Getenv("GOOGLE_PROJECT")
	return serviceSet

}

type domainSet map[string]Domain

func main() {

	services := getServiceSet()

	go func() {
		http.Handle("/metrics", promhttp.Handler())
		http.ListenAndServe(":8080", nil)
	}()

	myIP, err := lookupMyIP()
	ifErrorPanic(err)

	domains, err := getDomains(services)
	ifErrorPanic(err)
	newIP, err := updateDomains(services, domains, myIP)
	ifErrorPanic(err)
	currentIP := newIP

	for {
		myIP, err = lookupMyIP()
		if err != nil {
			log.Println("Error:", err.Error())
			continue
		}
		newDomains, err := getDomains(services)
		if err != nil {
			log.Println("Error:", err.Error())
			continue
		}
		if domainsChanged(domains, newDomains) || myIP != currentIP {
			if myIP != currentIP {
				log.Printf("IP changed from %s to %s", currentIP, myIP)
			} else {
				log.Printf("Domain change detected, %d before, now %d", len(domains), len(newDomains))
			}
			domains = newDomains
			newIP, err = updateDomains(services, domains, myIP)
			if err != nil {
				log.Println("Error:", err.Error())
				continue
			}
			currentIP = newIP
		}
		time.Sleep(5 * time.Second)
	}
}

func lookupMyIP() (string, error) {
	resp, err := http.Get("http://ipecho.net/plain")
	if err != nil {
		errorsOccurred.With(prometheus.Labels{"type": "lookupMyIP:curl", "domain": ""}).Inc()
		return "", err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		errorsOccurred.With(prometheus.Labels{"type": "lookupMyIP:ReadAll", "domain": ""}).Inc()
		return "", err
	}
	return string(body), err
}

func domainsChanged(oldDomains, newDomains domainSet) bool {
	oldKeys := make([]string, len(oldDomains))
	for k := range oldDomains {
		oldKeys = append(oldKeys, k)
	}
	sort.Strings(oldKeys)
	old := strings.Join(oldKeys, "|")
	newKeys := make([]string, len(newDomains))
	for k := range newDomains {
		newKeys = append(newKeys, k)
	}
	sort.Strings(newKeys)
	new := strings.Join(newKeys, "|")

	return old != new
}

func lookupIPViaGoogle(services serviceSet, zone, domain string) (string, error) {
	recordSets, err := services.dns.ResourceRecordSets.List(services.googleProject, zone).Do()
	apiCalls.With(prometheus.Labels{"type": "list", "domain": domain}).Inc()
	if err != nil {
		apiCallErrors.With(prometheus.Labels{"type": "list", "domain": domain}).Inc()
		errorsOccurred.With(prometheus.Labels{"type": "lookupIPViaGoogle:dns-list", "domain": domain}).Inc()
		return "", err
	}
	dottedDomain := domain + "."
	for _, recordSet := range recordSets.Rrsets {
		if recordSet.Name == dottedDomain && recordSet.Type == "A" {
			if len(recordSet.Rrdatas) == 0 {
				errorsOccurred.With(prometheus.Labels{"type": "no-ip-found", "domain": domain}).Inc()
				return "", fmt.Errorf("Domain %s did not return an IP", domain)
			} else if len(recordSet.Rrdatas) > 1 {
				errorsOccurred.With(prometheus.Labels{"type": "multiple-ips-found", "domain": domain}).Inc()
				return "", fmt.Errorf("Domain %s multiple IPs. This is not supported", domain)
			}
			return recordSet.Rrdatas[0], nil
		}
	}
	return "x.x.x.x", nil
}

func getDomains(services serviceSet) (domainSet, error) {
	ingresses, err := services.k8s.ExtensionsV1beta1().Ingresses("").List(metav1.ListOptions{})
	if err != nil {
		errorsOccurred.With(prometheus.Labels{"type": "k8s-list-ingresses", "domain": ""}).Inc()
		return nil, err
	}
	domains := domainSet{}

	ingressCounter := 0
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
		ingressCounter++

		for _, rule := range ingress.Spec.Rules {
			ip, err := lookupIPViaGoogle(services, zone, rule.Host)
			if err != nil {
				log.Printf("Skipping %s: %s", rule.Host, err)
				continue
			}
			domains[rule.Host] = Domain{zone, rule.Host, ip}
		}
	}
	ingressCount.Set(float64(ingressCounter))
	domainCount.Set(float64(len(domains)))
	return domains, nil
}

func updateDomains(services serviceSet, domains domainSet, myIP string) (string, error) {

	for _, domain := range domains {
		log.Printf("Checking %s: %s <-> %s", domain.Name, domain.IP, myIP)
		domainsChecked.With(prometheus.Labels{"domain": domain.Name}).Inc()
		if domain.IP != myIP {
			err := updateDNS(services, domain, myIP)
			if err != nil {
				return "", err
			}
			domainsUpdated.With(prometheus.Labels{"domain": domain.Name}).Inc()
		}
	}
	return myIP, nil
}

func updateDNS(services serviceSet, domain Domain, myIP string) error {
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
	if domain.IP != "x.x.x.x" {
		change.Deletions = append(change.Deletions, &deletion)
	}

	_, err := services.dns.Changes.Create(services.googleProject, domain.Zone, change).Do()
	apiCalls.With(prometheus.Labels{"type": "change", "domain": domain.Name}).Inc()
	if err != nil {
		apiCallErrors.With(prometheus.Labels{"type": "change", "domain": domain.Name}).Inc()
		errorsOccurred.With(prometheus.Labels{"type": "updateDNS:dns-change", "domain": domain.Name}).Inc()
		return err
	}

	log.Printf("Update complete for %s", domain.Name)

	return nil
}

package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"

	"github.com/go-git/go-git/v5"
	gitHTTP "github.com/go-git/go-git/v5/plumbing/transport/http"
)

var repo *git.Repository
var worktree *git.Worktree

func InitialiseGit() error {
	gitURL := os.Getenv("GIT_URL")
	gitUser := os.Getenv("GIT_USER")
	gitPass := os.Getenv("GIT_PASS")
	checkoutPath := os.Getenv("CHECKOUT_PATH")
	log.Println("initialising git repository")
	var err error
	repo, err = git.PlainClone(checkoutPath, false, &git.CloneOptions{
		URL: gitURL,
		Auth: &gitHTTP.BasicAuth{
			Username: gitUser,
			Password: gitPass,
		},
		Progress: os.Stdout,
	})
	if err != nil {
		return err
	}
	worktree, err = repo.Worktree()
	return err
}

func Pull() error {
	log.Println("pulling git repository")
	gitUser := os.Getenv("GIT_USER")
	gitPass := os.Getenv("GIT_PASS")
	err := worktree.Pull(&git.PullOptions{RemoteName: "origin",
		Auth: &gitHTTP.BasicAuth{
			Username: gitUser,
			Password: gitPass,
		}})
	if err != nil {
		if err.Error() == "already up-to-date" {
			log.Println("Already up-to-date")
		} else {
			return err
		}
	}
	ref, err := repo.Head()
	if err != nil {
		return err
	}
	log.Printf("Pulled commit %s", ref.Hash())
	return nil
}

func Mkdocs() error {
	cmd := exec.Command("mkdocs", "build", "-f", "site/mkdocs.yml", "-d", "/usr/local/apache2/htdocs")
	out, err := cmd.CombinedOutput()
	log.Println(string(out))
	if err != nil {
		return err
	}
	return nil
}

func Hugo() error {
	cmd := exec.Command("hugo", "-d", "/usr/local/apache2/htdocs")
	out, err := cmd.CombinedOutput()
	log.Println(string(out))
	if err != nil {
		return err
	}
	return nil
}

func HandleGitLabWebHook(w http.ResponseWriter, req *http.Request) {
	webhookToken := os.Getenv("WEBHOOK_TOKEN")
	if req.Header.Get("X-Gitlab-Token") != webhookToken {
		http.Error(w, "Not found", 404)
	}

	err := Pull()
	if err != nil {
		log.Println("Error pulling: ", err)
		http.Error(w, err.Error(), 500)
		return
	}
	err = Hugo()
	if err != nil {
		log.Println("Error calling Hugo: ", err)
		http.Error(w, err.Error(), 500)
		return
	}
	fmt.Fprintf(w, "Okay")
}

func main() {
	err := InitialiseGit()
	if err != nil {
		panic(err)
	}
	err = Hugo()
	if err != nil {
		panic(err)
	}
	http.HandleFunc("/gitlab-webhook", HandleGitLabWebHook)
	http.ListenAndServe(":8989", nil)
}

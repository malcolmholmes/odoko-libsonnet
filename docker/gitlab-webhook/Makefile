.PHONY: docker push

docker:
	docker build -t registry.gitlab.com/odoko/web/gitlab-webhook .

push: docker
	docker push registry.gitlab.com/odoko/web/gitlab-webhook

run:
	docker build -t registry.gitlab.com/odoko/web/gitlab-webhook .
#	docker run -v `pwd`:/stuff -it --entrypoint="sh" -p 8000:8000 registry.gitlab.com/odoko/web/gitlab-webhook
	docker run -v `pwd`:/stuff -it --entrypoint=mkdocs -p 8000:8000 -w /stuff/site registry.gitlab.com/odoko/web/gitlab-webhook serve -a 0.0.0.0:8000

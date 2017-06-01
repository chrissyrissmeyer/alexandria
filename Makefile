APP := $(wildcard app/**/*.rb)
LIB := $(wildcard lib/**/*.rb)
DOC := $(wildcard doc/*.md)

html/index.html: README.md $(DOC) $(APP) $(LIB)
	bundle exec yardoc

html: html/index.html

BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD | tr -d '\n')

.PHONY: prod rubocop spec vagrant

prod:
	bundle exec cap production deploy

cops:
	bundle exec rubocop --format simple --config .rubocop.yml --parallel

spec:
	CI=1 RAILS_ENV=test bundle exec rake ci --trace

vagrant:
	SERVER=127.0.0.1 BRANCH_NAME=$(BRANCH) REPO=/vagrant bundle exec cap vagrant deploy

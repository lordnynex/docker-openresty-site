.PHONY: build clean

build: clean
	bundle install
	bundle package --all
	bundle exec docker-template openresty-sitedev

clean:
	bundle clean --force
	rm -rf vendor/*
	rm -rf Gemfile.lock

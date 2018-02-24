GOPATH := $(shell go env GOPATH)
GODEP_BIN := $(GOPATH)/bin/dep
GOLINT := $(GOPATH)/bin/golint
version := $(shell cat VERSION)-$(shell git rev-parse --short HEAD)

packages = $$(go list ./... | egrep -v '/vendor/')
files = $$(find . -name '*.go' | egrep -v '/vendor/')

ifeq "$(host_build)" "yes"
	# use host system for building
	BUILD_SCRIPT =./build-deb-host.sh
else
	# use docker for building
	BUILD_SCRIPT = ./build-deb-docker.sh
endif


.phony: all
all: lint vet test build 

godep:
	go get -u github.com/golang/dep/cmd/dep

gopkg.toml: godep
	$(GODEP_BIN) init

vendor:         ## vendor the packages using dep
vendor: godep Gopkg.toml Gopkg.lock
	@ echo "no vendor dir found. fetching dependencies now..."
	$(GODEP_BIN) ensure

version:
	@ echo $(VERSION)

build:          ## Build the binary
build: vendor
	test $(BINARY_NAME)
	go build -o $(BINARY_NAME) -ldflags "-X main.Version=$(VERSION)" 

build-deb:      ## Build DEB package (needs other tools)
	test $(BINARY_NAME)
	test $(DEB_PACKAGE_NAME)
	test "$(DEB_PACKAGE_DESCRIPTION)"
	exec ${BUILD_SCRIPT}
	
test: vendor
	go test -race $(packages)

vet:            ## Run go vet
vet: vendor
	go tool vet -printfuncs=Debug,Debugf,Debugln,Info,Infof,Infoln,Error,Errorf,Errorln $(files)

lint:           ## Run go lint
lint: vendor $(GOLINT)
	go get -u golang.org/x/lint/golint
	$(GOLINT) -set_exit_status $(packages)

clean:
	test $(BINARY_NAME)
	rm -f $(BINARY_NAME) 

help:           ## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'


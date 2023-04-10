
venv:
	# create a virtual environment in R with Packrat
	Packrat::init()
	
activate:
	# activate venv run this manually
	
install:
	# install dependencies
	Packrat::restore()

docstring:
	# format docstring
	docstring("project.R")
	
format:
	#format code
	tidy_source("project.R")
lint:
	#flake8 or #pylint
	lintr("project.R")
test:
	#test
	testthat::test_dir("tests/testthat")

build:
	# build the container: More important for the CI/CD
	sudo docker build -t data-privacy-env:v1 .
	
run:
	# run the container
	sudo docker run -p 8888:8888 data-privacy-env:v1

all: venv activate install build run
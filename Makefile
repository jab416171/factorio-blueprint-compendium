%.exchange: %.json
	./scripts/to_exchange.py $< > $@

all: $(addsuffix .exchange, $(basename $(wildcard blueprints/belt/balancer/smallest/*.json)))
test: $(addsuffix .exchange, $(basename $(wildcard blueprints/belt/balancer/smallest/*.json)))
clean:
	find . -type f -name *.exchange -delete

TUR_FILES=$(wildcard *.tur)

post:
	iverilog -g2005-sv -o out post.v

compile-all:
	python3 turasm.py $(TUR_FILES)

clean:
	rm -f out
	rm -f *.tbc



CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -pthread -Wall -Wextra
LDFLAGS ?=

all: mcd_debugd

mcd_debugd: mcd_debugd.cpp
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS)

check-web:
	python3 -m py_compile mcd_debug_web.py

check-mcp:
	python3 -m py_compile mcd_debug_mcp.py

clean:
	rm -f mcd_debugd

.PHONY: all check-web check-mcp clean

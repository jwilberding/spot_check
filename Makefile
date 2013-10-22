ERLFLAGS= -pa $(CURDIR)/.eunit -pa $(CURDIR)/ebin

DEPS_PLT=$(CURDIR)/.deps_plt

# =============================================================================
# Verify that the programs we need to run are installed on this system
# =============================================================================
ERL = $(shell which erl)

ifeq ($(ERL),)
$(error "Erlang not available on this system")
endif

REBAR=$(shell which rebar)

ifeq ($(REBAR),)
REBAR=$(CURDIR)/rebar
endif

# =============================================================================
# Handle version discovery
# =============================================================================

# We have a problem that we only have 10 minutes to build on travis
# and those travis boxes are quite small. This is ok for the fast
# dialyzer on R15 and above. However on R14 and below we have the
# problem that travis times out. The code below lets us not run
# dialyzer on R14
OTP_VSN=$(shell erl -noshell -eval 'io:format("~p", [erlang:system_info(otp_release)]), erlang:halt(0).' | perl -lne 'print for /R(\d+).*/g')
TRAVIS_SLOW=$(shell expr $(OTP_VSN) \<= 15 )

ifeq ($(TRAVIS_SLOW), 0)
DIALYZER=$(shell which dialyzer)
else
DIALYZER=: not running dialyzer on R14 or R15
endif

.PHONY: all compile doc clean test dialyzer typer shell distclean pdf \
	update-deps clean-common-test-data rebuild

all: deps compile

# =============================================================================
# Rules to build the system
# =============================================================================

REBAR_URL=https://github.com/rebar/rebar/wiki/rebar
$(REBAR):
	curl -Lo rebar $(REBAR_URL) || wget $(REBAR_URL)
	chmod a+x rebar

get-rebar: $(REBAR)

deps: $(REBAR)
	$(REBAR) get-deps
	$(REBAR) compile

update-deps: $(REBAR)
	$(REBAR) update-deps
	$(REBAR) compile

compile: $(REBAR)
	$(REBAR) skip_deps=true compile

doc:
	$(REBAR) skip_deps=true doc

eunit: compile clean-common-test-data
	$(REBAR) skip_deps=true eunit

test: compile dialyzer eunit

$(DEPS_PLT): compile
	@echo Building local erts plt at $(DEPS_PLT)
	@echo
	$(DIALYZER) --output_plt $(DEPS_PLT) --build_plt \
	   --apps erts kernel stdlib

dialyzer: compile $(DEPS_PLT)
	$(DIALYZER) --fullpath --plt $(DEPS_PLT) \
	 -Wrace_conditions -r ./ebin

typer:
	typer --plt $(DEPS_PLT) -r ./src

shell: deps compile
# You often want *rebuilt* rebar tests to be available to the
# shell you have to call eunit (to get the tests
# rebuilt). However, eunit runs the tests, which probably
# fails (thats probably why You want them in the shell). This
# runs eunit but tells make to ignore the result.
	- @$(REBAR) skip_deps=true eunit
	@$(ERL) $(ERLFLAGS)

pdf:
	pandoc README.md -o README.pdf

clean-common-test-data:
# We have to do this because of the unique way we generate test
# data. Without this rebar eunit gets very confused
	- rm -rf $(CURDIR)/test/*_SUITE_data

clean: clean-common-test-data $(REBAR)
	- rm -rf $(CURDIR)/test/*.beam
	- rm -rf $(CURDIR)/logs
	- rm -rf $(CURDIR)/ebin
	$(REBAR) skip_deps=true clean

distclean: clean
	- rm -rf $(DEPS_PLT)
	- rm -rvf $(CURDIR)/deps

rebuild: distclean deps compile dialyzer test

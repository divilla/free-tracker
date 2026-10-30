.PHONY: unit-test end-to-end-test

unit-test:
	python3 tool/run_tests.py unit

end-to-end-test:
	python3 tool/run_tests.py e2e

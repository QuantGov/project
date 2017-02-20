TARGET_CORPUS = /path/to/target/corpus
ESTIMATOR = /path/to/estimator
NAME = results
TODAY := $(shell python -c "import datetime; print(datetime.datetime.now().strftime('%Y%m%d'))")

run: data/$(NAME)
freeze: data/$(NAME)
	python -m zipfile -c data/$(NAME)-$(TODAY).zip $(wildcard data/$(NAME)/*)

data/$(NAME): data/results.csv
	rm -rf $@
	mkdir $@
	$(MAKE) -C $(TARGET_CORPUS) data/metadata.csv
	cp $(TARGET_CORPUS)/data/metadata.csv $@
	cp data/results.csv $@

data/results.csv:
	$(MAKE) -C $(ESTIMATOR) TARGET_CORPUS=$(TARGET_CORPUS) RESULTS=$(abspath $@) $(abspath $@)

check_estimator:
	$(MAKE) -C $(ESTIMATOR) evaluate


.PHONY: estimate check_estimator check_target data/results.csv

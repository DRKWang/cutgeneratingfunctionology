SAGE=sage

SAGEFILES =					\
	bug_examples.sage			\
	compendium_procedures.sage		\
	continuous_case.sage			\
	discontinuous_case.sage			\
	extreme_functions_in_literature.sage	\
	functions.sage				\
	simple_extremality_test.sage		\
	survey_examples.sage 			\
	extreme_functions_mlr_cpl3.sage		\
	quasi_periodic.sage

all:
	@echo "No need to 'make' anything. Just run it in Sage; see README.rst"

install:
	@echo "No need to install anything. Just run it in Sage; see README.rst"

check:
	$(SAGE) -tp 4 $(SAGEFILES)

tags: $(SAGEFILES)
	etags $(SAGEFILES)

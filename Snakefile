#### PROJECT SNAKEFILE #########################################################
## This file defines a workflow for a QuantGov project as executed by the
## SnakeMake utility. The default project uses a single QuantGov Estimator to
## predict a value for the documents in a single QuantGov Corpus.


#### PYTHON IMPORTS ###########################################################
## This section imports libraries and defines functionality to be used
## throughout the workflow 
 
import os.path
import datetime
import zipfile

from pathlib import Path

def outpath(path):
    """Ensure Cross-Platform functionality for files in subdirectories"""
    return os.path.sep.join(os.path.split(str(path)))


def get_component_name(path):
    """Guess a component's name from the folder containing it"""
    path = Path(path)
    if path.stem.startswith('corpus-') or path.stem.startswith('estimator-'):
        return path.stem.split('-', 1)[-1]
    else:
        return path.stem

 
#### SNAKEFILE CONFIGURATION ##################################################
## This section defines snakfile configuration and variables used throughout
## the workflow

configfile: 'config.yaml'

subworkflow estimator:
    workdir: config['estimator']
    configfile: 'config.yaml'

subworkflow target_corpus:
    workdir: config['target_corpus']
    configfile: 'config.yaml'

target_name = get_component_name(config['target_corpus'])
estimator_name = get_component_name(config['estimator'])
dataset_dir = Path('data').joinpath(config['name'])
timestamp_format = '%Y%m%d-%H%M' # See Python datetime documentation


#### ESTIMATION ###############################################################
## This section defines the rule which performs the estimation on the target
## Corpus

rule estimate:
    input: 
        estimator('data/vectorizer.pickle'),
        estimator('data/model.pickle'),
        target_corpus('timestamp')
    params:
        '--probability' if config['probability'] else ''
    output:
        outpath('data/results.csv')
    shell:
        'quantgov estimator estimate {input} --outfile {output} {params}'


#### DATASET CREATION #########################################################
## This section packages files together in a dataset folder and archive. This
## is where to define any "finishing" tasks, such as renaming files or
## variables

metadata = dataset_dir.joinpath('{}_metadata.csv'.format(target_name))
results = dataset_dir.joinpath('{}_{}_{}.csv'.format(
    target_name, estimator_name, config['prediction_type']))

rule create_dataset:
    input:
        target_corpus('data/metadata.csv'),
        rules.estimate.output
    output:
        outpath(metadata),
        outpath(results)
    run:
        import shutil
        try:
            shutil.rmtree(str(dataset_dir))
        except FileNotFoundError:
            pass
        dataset_dir.mkdir(parents=True)
        for infile, outfile in zip(input, output):
            print('Copying {} to {}'.format(infile, outfile))
            shutil.copy(infile, outfile)

try: # Define dataset timestamp for archive
    dataset_time = (
        datetime.datetime
        .fromtimestamp(dataset_dir.stat().st_mtime)
        .strftime(timestamp_format)
    )
except FileNotFoundError:
    dataset_time = datetime.datetime.now().strftime(timestamp_format)

rule create_archive:
    input:
        rules.create_dataset.output
    output:
        outpath('data/{}_{}.zip'.format(config['name'], dataset_time))
    run:
        import zipfile
        with zipfile.ZipFile(output[0], 'w') as zf:
            for i in input:
                zf.write(i, str(Path(i).relative_to(dataset_dir)))

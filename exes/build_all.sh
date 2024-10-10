docker build -t stavisvols/params_parser -f params_parser.dockerfile ./
docker push stavisvols/params_parser

docker build -t stavisvols/comet_for_pipeline -f comet.dockerfile ./
docker push stavisvols/comet_for_pipeline

docker build -t stavisvols/percolator_for_pipeline -f percolator.dockerfile ./
docker push stavisvols/percolator_for_pipeline

docker build -t stavisvols/dinosaur_for_pipeline -f dinosaur.dockerfile ./
docker push stavisvols/dinosaur_for_pipeline

docker build -t stavisvols/feature_mapper -f feature_mapper.dockerfile ./
docker push stavisvols/feature_mapper

docker build -t stavisvols/eggnog_for_pipeline -f eggnog.dockerfile ./
docker push stavisvols/eggnog_for_pipeline

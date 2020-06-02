:- use_module(library(crypto)).

go:-
    crypto_data_hash(test,Sigelo,[algorithm(sha384),hmac(test)]),
    writeln(Sigelo).
:- use_module(library(crypto)).

sigelilo(Sg) :- getenv('SIGELILO',Sg).
retadreso(R) :- getenv('RETADRESO',R).
gist(G) :- current_prolog_flag(argv,[G|_]).

%:- initialization(go,main).

go :-
    retadreso(R),
    gist(G),
    format(atom(File),'dict/xml/~w.xml',[G]),
    read_file_to_codes(File,Codes,[]),
    atom_codes(Xml,Codes),
    sigelo(R,Xml,Sigelo),
    format('sigelo: ~w~n',[Sigelo]),
    line_sums(R,S1),
    line_sums(Xml,S2),
    format('~w,~w',[S1,S2]).

sigelo(Retadreso,Quoted,Sigelo) :-
    sigelilo(Sigelilo),
    format('|~w|~w|~n',[Retadreso,Sigelilo]),
    %agordo:get_config(sigelilo,Sigelilo),
    atomic_list_concat([Retadreso,Quoted],'\n',Data),
    crypto_data_hash(Data,Sigelo,[algorithm(sha256),hmac(Sigelilo)]).


line_sums(Xml,Sums) :-
    atomic_list_concat(Lines,'\n',Xml),
    line_sums_(Lines,S),
    atomic_list_concat(S,',',Sums).  
  
  line_sums_([],[]).
  line_sums_([L|Lines],[S|Sums]):-
    atom_length(L,Len),
    sha_hash(L,[H1,H2|_],[]),
    hash_atom([H1,H2],H),
    format(atom(S),'~w-~w',[Len,H]),
    line_sums_(Lines,Sums).
  
  gist_html_url(json(KV),json([html_url=Url])) :-
      member(html_url=Url,KV).
  
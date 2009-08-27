-module(store) .

-author("Antonio Garrote Hernández") .

-include_lib("eunit/include/eunit.hrl") .

-export([insert/3, next/2, delete/3, all/2, delete_if/2]) .

%% @doc
%% Inserts a new value in one of the queues identified by Key.
-spec(insert(atom(), any(), [{atom(),[any()]}]) -> [{atom(),[any()]}]) .

insert(Key,Value,Queues) ->
    DoInsert = fun(_F,K,V,[],A)              -> [{K,[V]} | A] ;
                 (_F,K,V,[{K,Vs} | T], A)    -> A ++ [{K, lists:reverse([V|Vs])} | T] ;
                 (F,K,V,[{_K,_Vs}=H | T], A) -> F(F,K,V,T,[H|A])
               end ,
    DoInsert(DoInsert,Key,Value,Queues,[]) .


%% @doc
%% retrieves the next element in the circular queue
-spec(next(atom(), [{atom(),[any()]}]) -> {atom(), [{atom(),[any()]}]}) .

next(Key,Queues) ->
    DoNext = fun(_F,_K,[],_A)               -> not_found ;
                (_F,K,[{K,[VH|VR]} | R], A) -> {VH, [{K, VR ++ [VH]} | R] ++ A} ; %% we found the queue
                (F,K,[{_K,_Vs} = H | R], A) -> F(F,K,R,[H|A])
             end ,
    DoNext(DoNext,Key,Queues,[]) .

%% @doc
%% retrieves all the elements for a key
-spec(all(atom(), [{atom(),[any()]}]) -> [any()]) .

all(Key,Queues) ->
    DoAll = fun(_F,_K,[],_A)             -> [] ;
               (_F,K,[{K,Vs} | _R], _A)  -> Vs ; %% we found the queue
               (F,K,[H | R], A)          -> F(F,K,R,[H|A])
            end ,
    DoAll(DoAll,Key,Queues,[]) .


%% @doc
%% Deletes Value from queue Key .
-spec(delete(atom(), any(), [{atom(),[any()]}]) -> [{atom(),[any()]}]).

delete(Key,Value, Queues) ->
    DoDelete = fun(_F,_K,[],_A)               -> erlang:error(unknown_queue) ;
                (_F,K,[{K,Vs} | R], A)        -> [{K, lists:delete(Value,Vs)} | R] ++ A ; %% we found the queue
                (F,K,[{_K,_Vs} = H | R], A)   -> F(F,K,R,[H|A])
             end ,
    DoDelete(DoDelete,Key,Queues,[]) .


%% @doc
%% Deletes one value from all the queues if the
%% given predicate P returns true.
delete_if(P, Queues) ->
    Pp = fun(X) -> not(P(X)) end,
    DoDeleteP = fun(_F,_Pr,[],A)            -> A ;
                   (F,Pr,[{K,Vs} | R], A)   -> VsP = lists:filter(Pr,Vs),
                                               F(F,P,R,[{K,VsP} | A])
                end ,
    DoDeleteP(DoDeleteP, Pp, Queues, []) .

%% @doc
%% Deletes one value from all the queues if the
%% given predicate P returns true.
dequeue_if(P, Queues) ->
    Pp = fun(X) -> not(P(X)) end,
    DoDeleteP = fun(_F, [], A) ->
                        A ;

                   (F, [{K,Vs} | R], {V, A})   ->
                        case lists_extensions:detect(P,Vs) of
                            {ok, Vp}          ->  VsP = lists:filter(Pp,Vs),
                                                  F(F, R, {Vp,[{K,VsP}|A]}) ;
                            {error,not_found} -> F(F, R, {V, [{K,Vs}|A]})
                        end

                end ,
    DoDeleteP(DoDeleteP, Queues, {not_found,[]}) .


%% @doc
%% Deletes Value from all the Queues.
-spec(delete_from_all(atom(), [{atom(),[any()]}]) -> [{atom(),[any()]}]).

delete_from_all(Value,Queues) ->
    lists:map(fun({K,Vs}) -> {K,lists:delete(Value,Vs)} end, Queues) .


%% tests


insertion_test() ->
    Queue = insert(test,1,[]),
    ?assertEqual(1,length(Queue)),
    QueueB = insert(test,2,Queue),
    ?assertEqual(1,length(QueueB)),
    {_K,Vs} = lists:nth(1,QueueB),
    ?assertEqual(2,length(Vs)) .

next_test() ->
    QueueA = insert(test,1,[]),
    QueueB = insert(test,2,QueueA),
    QueueC = insert(test_2,3,QueueB),
    {ElemA,QueueD} = next(test,QueueC),
    ?assertEqual(1,ElemA),
    {ElemB,QueueE} = next(test,QueueD),
    ?assertEqual(2,ElemB),
    {ElemC,QueueF} = next(test,QueueE),
    ?assertEqual(1,ElemC),
    ?assertEqual(2,length(QueueF)) .

deletion_test() ->
    Queue = insert(test,1,[]),
    QueueB = insert(test,2,Queue),
    QueueC = delete(test,1,QueueB),
    {_K,Vs} = lists:nth(1,QueueC),
    ?assertEqual(1,length(Vs)),
    ?assertEqual(2,lists:nth(1,Vs)) .

deletion_from_all_test() ->
    Queue = insert(test,1,[]),
    QueueB = insert(test,2,Queue),
    QueueC = insert(test_2,1,QueueB),
    QueueD = delete_from_all(1,QueueC),
    lists:foreach(fun({_K,V}) ->
                          ?assertEqual(false, lists:any(fun(Vp) ->
                                                                Vp =:= 1
                                                        end, V))
                  end,QueueD) .

all_test() ->
    Queue = insert(test,1,[]),
    QueueB = insert(test,2,Queue),
    ?assertEqual(2, length(all(test,QueueB))) .


dequeue_if_test() ->
    Queues = [{a,[1,2,3,4]}, {b,[1,2,3]}, {c,[5,6,7]}],
    {Val,Queuesp} = dequeue_if(fun(X) -> X=:=2 end, Queues),
    ?assertEqual(2,Val),
    ?assertEqual(3, length(Queuesp)),
    lists:foreach(fun({_Id,Es}) ->
                          ?assertEqual(false, lists:any(fun(E) -> E=:=2 end, Es))
                  end, Queuesp) .


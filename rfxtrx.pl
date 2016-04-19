:- module(rfxtrx,[run/0]).
:- use_module(library(socket)).
:- use_module(library(lists)).

run() :- 
tcp_connect('192.168.0.20':10001, StreamPair, []),
put_bytes(StreamPair, [13,0,0,0,0,0,0,0,0,0,0,0,0,0]), % Reset
sleep(0.5),
put_bytes(StreamPair, [13,0,0,1,2,0,0,0,0,0,0,0,0,0]), % Status
read_rfxtrx(StreamPair,[]).

% Main loop
read_rfxtrx(StreamPair,List) :-
	get_byte(StreamPair, Byte), 
	reverse(List, List1),       
	reverse([Byte|List1],List2), 
	check(StreamPair,List2,List3),         
	read_rfxtrx(StreamPair,List3).


% Command ack from rfxtrx
check(_StreamPair,[4,2,1,_,_],[]).
% This clause discards 0-length messages
check(StreamPair,[0|Rest],Rest1) :- check(StreamPair,Rest,Rest1).
% Lighting1 devices such as X10 motion detector
% Housecode are a=65, b=66 and so on
% Commands are 0=off, 1=on, 2=dim, 3=bright, 5=groupoff, 6=groupon, 7=chime, 255=illegal command
check(_StreamPair,[7,16,0,_Seqnr,_Housecode,_Unitcode,Command,_],[]) :- 
	format("Message 16, Command is ~p~n",Command).
% Lighting2 devices such as NEXA remote control
% Commands are 0=off, 1=on, 2=setlevel, 3=groupoff, 4=groupon, 5=setgrouplevel
check(_StreamPair,[11,17,0,_Seqnr,H1,H2,H3,H4,_Unitcode,Command,_Level,_Rssi],[]) :- 
	Housecode is H4  \/ H3<<8  \/ H2<<16  \/ H1<<24, format("Message 17, Housecode is ~p and Command is ~p~n",[Housecode,Command]).
% Weather station, temperature and humidity data
check(_StreamPair,[10,82,_Type,_Seqnr,_Id1,_Id2,_Temp1,_Temp2,_Humidity,_,_],[]) :- 
	format("Message 82~n").
% Weather stations, Wind data
check(_StreamPair,[16,86,2,_Seqnr,_Id1,_Id2,_Direction1,_Direction2,_Average1,_Average2,_Gust1,_Gust2,_,_,_,_,_Batteryrssi],[]) :- 
	format("Message 86~n").
% This clause is true for all unknown/irrelevant messages. They are all discarded.
check(_StreamPair,[N|Rest],[]) :- length(Rest, N), format("Unknown is ~p~n",[Rest]).
% This clause is allways true. If a message is not completely downloaded yet, we just return the current buffer.
check(_,L,L) :- format("L is ~p~n",[L]).


put_bytes(Stream, List) :- 
        maplist(put_byte(Stream), List), 
        flush_output(Stream). 


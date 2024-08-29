(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    `$$prompt,
    `$noSemanticSearch,
    `getSmallContextString,
    `insertContextPrompt,
    `makeChatTranscript,
    `vectorDBSearch
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$prompt = $$string | { $$string... } | $$chatMessages;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
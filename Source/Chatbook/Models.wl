(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Models`" ];

(* cSpell: ignore chatgpt *)

(* :!CodeAnalysis::BeginBlock:: *)

`getModelList;
`toModelName;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Actions`"  ];
Needs[ "Wolfram`Chatbook`Dynamics`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$$modelVersion = DigitCharacter.. ~~ (("." ~~ DigitCharacter...) | "");

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenAI Models*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getModelList*)
getModelList // beginDefinition;

(* NOTE: This function is also called in UI.wl *)
getModelList[ ] := getModelList @ toAPIKey @ Automatic;

getModelList[ key_String ] := getModelList[ key, Hash @ key ];

getModelList[ Missing[ "DialogInputNotAllowed" ] ] := $fallbackModelList;

getModelList[ key_String, hash_Integer ] :=
    Module[ { resp },
        resp = URLExecute[
            HTTPRequest[
                "https://api.openai.com/v1/models",
                <| "Headers" -> <| "Content-Type" -> "application/json", "Authorization" -> "Bearer "<>key |> |>
            ],
            "RawJSON",
            Interactive -> False
        ];
        If[ FailureQ @ resp && StringStartsQ[ key, "org-", IgnoreCase -> True ],
            (*
                When viewing the account settings page on OpenAI's site, it describes the organization ID as something
                that's used in API requests, which may be confusing to someone who is looking for their API key and
                they come across this page first. This message is meant to catch these cases and steer the user in the
                right direction.

                TODO: When more services are supported, this should only apply when using an OpenAI endpoint.
            *)
            throwFailure[
                ChatbookAction::APIKeyOrganizationID,
                Hyperlink[ "https://platform.openai.com/account/api-keys" ],
                key
            ],
            getModelList[ hash, resp ]
        ]
    ];

(* Could not connect to the server (maybe server is down or no internet connection available) *)
getModelList[ hash_Integer, failure: Failure[ "ConnectionFailure", _ ] ] :=
    throwFailure[ ChatbookAction::ConnectionFailure, failure ];

(* Some other failure: *)
getModelList[ hash_Integer, failure_? FailureQ ] :=
    throwFailure[ ChatbookAction::ConnectionFailure2, failure ];

getModelList[ hash_, KeyValuePattern[ "data" -> data_ ] ] :=
    getModelList[ hash, data ];

getModelList[ hash_, models: { KeyValuePattern[ "id" -> _String ].. } ] :=
    Module[ { result },
        result = Cases[ models, KeyValuePattern[ "id" -> id_String ] :> id ];
        getModelList[ _String, hash ] = result;
        updateDynamics[ "Models" ];
        result
    ];

getModelList[ hash_, KeyValuePattern[ "error" -> as: KeyValuePattern[ "message" -> message_String ] ] ] :=
    Catch @ Module[ { newKey, newHash },
        If[ StringStartsQ[ message, "Incorrect API key" ] && Hash @ systemCredential[ "OPENAI_API_KEY" ] === hash,
            newKey = If[ TrueQ @ $dialogInputAllowed, apiKeyDialog[ ], Throw @ $fallbackModelList ];
            newHash = Hash @ newKey;
            If[ StringQ @ newKey && newHash =!= hash,
                getModelList[ newKey, newHash ],
                throwFailure[ ChatbookAction::BadResponseMessage, message, as ]
            ],
            throwFailure[ ChatbookAction::BadResponseMessage, message, as ]
        ]
    ];

getModelList // endDefinition;


$fallbackModelList = { "gpt-3.5-turbo", "gpt-3.5-turbo-16k", "gpt-4" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toModelName*)
toModelName // beginDefinition;

toModelName[ { service_String, name_String } ] := toModelName @ name;

toModelName[ name_String? StringQ ] := toModelName[ name ] =
    toModelName0 @ StringReplace[
        ToLowerCase @ StringReplace[
            name,
            a_? LowerCaseQ ~~ b_? UpperCaseQ :> a<>"-"<>b
        ],
        "gpt"~~n:$$modelVersion~~EndOfString :> "gpt-"<>n
    ];

toModelName // endDefinition;

toModelName0 // beginDefinition;
toModelName0[ "chat-gpt"|"chatgpt"|"gpt-3"|"gpt-3.5" ] := "gpt-3.5-turbo";
toModelName0[ name_String ] := StringReplace[ name, "gpt"~~n:DigitCharacter :> "gpt-"<>n ];
toModelName0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SetModel*)
Options[SetModel]={"SetLLMEvaluator"->True}

SetModel[args___]:=Catch[setModel[args],"SetModel"]

setModel[model_,opts:OptionsPattern[SetModel]]:=setModel[$FrontEndSession,model,opts]

setModel[scope_,model_Association,opts:OptionsPattern[SetModel]]:=(
  If[TrueQ[OptionValue["SetLLMEvaluator"]],
  	System`$LLMEvaluator=System`LLMConfiguration[System`$LLMEvaluator,model];
  ];
  CurrentValue[scope, {TaggingRules, "ChatNotebookSettings"}] = Join[
		Replace[CurrentValue[scope, {TaggingRules, "ChatNotebookSettings"}],Except[_Association]-><||>,{0}],
		model
  ]
)

setModel[scope_,name_String,opts:OptionsPattern[SetModel]]:=Enclose[With[{model=ConfirmBy[standardizeModelName[name],StringQ]},
  If[TrueQ[OptionValue["SetLLMEvaluator"]],
  	System`$LLMEvaluator=System`LLMConfiguration[System`$LLMEvaluator,<|"Model"->model|>];
  ];
  CurrentValue[scope, {TaggingRules, "ChatNotebookSettings","Model"}] = model
]
]

setModel[___]:=$Failed

standardizeModelName[gpt4_String]:="gpt-4"/;StringMatchQ[StringDelete[gpt4,WhitespaceCharacter|"-"|"_"],"gpt4",IgnoreCase->True]
standardizeModelName[gpt35_String]:="gpt-3.5-turbo"/;StringMatchQ[StringDelete[gpt35,WhitespaceCharacter|"-"|"_"],"gpt3.5"|"gpt3.5turbo",IgnoreCase->True]
standardizeModelName[name_String]:=name

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];

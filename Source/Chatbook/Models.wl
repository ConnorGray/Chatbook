(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Models`" ];

(* cSpell: ignore chatgpt *)

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `chatModelQ;
    `chooseDefaultModelName;
    `getModelList;
    `modelDisplayName;
    `multimodalModelQ;
    `snapshotModelQ;
    `standardizeModelData;
    `resolveFullModelSpec;
    `toModelName;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Actions`"  ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Dynamics`" ];
Needs[ "Wolfram`Chatbook`Services`" ];
Needs[ "Wolfram`Chatbook`UI`"       ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$$modelVersion = DigitCharacter.. ~~ (("." ~~ DigitCharacter...) | "");

$defaultModelIcon = "";

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
(* ::Section::Closed:: *)
(*Model Utility Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatModelQ*)
chatModelQ // beginDefinition;
chatModelQ[ _? (modelContains[ "instruct" ]) ] := False;
chatModelQ[ _? (modelContains[ StartOfString~~("gpt"|"ft:gpt") ]) ] := True;
chatModelQ[ _String ] := False;
chatModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelContains*)
modelContains // beginDefinition;
modelContains[ patt_ ] := modelContains[ #, patt ] &;
modelContains[ m_String, patt_ ] := StringContainsQ[ m, WordBoundary~~patt~~WordBoundary, IgnoreCase -> True ];
modelContains // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelName*)
modelName // beginDefinition;
modelName[ KeyValuePattern[ "Name" -> name_String ] ] := modelName @ name;
modelName[ name_String ] := toModelName @ name;
modelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toModelName*)
toModelName // beginDefinition;

toModelName[ KeyValuePattern @ { "Service" -> service_, "Name"|"Model" -> model_ } ] :=
    toModelName @ { service, model };

toModelName[ KeyValuePattern[ "Name"|"Model" -> model_ ] ] :=
    toModelName @ model;

toModelName[ { service_String, name_String } ] := toModelName @ name;

toModelName[ name_String? StringQ ] := toModelName[ name ] =
    If[ StringMatchQ[ name, "ft:"~~__~~":"~~__ ],
        name,
        toModelName0 @ StringReplace[
            ToLowerCase @ StringReplace[
                name,
                a_? LowerCaseQ ~~ b_? UpperCaseQ :> a<>"-"<>b
            ],
            "gpt"~~n:$$modelVersion~~EndOfString :> "gpt-"<>n
        ]
    ];

toModelName // endDefinition;

toModelName0 // beginDefinition;
toModelName0[ "chat-gpt"|"chatgpt"|"gpt-3"|"gpt-3.5" ] := "gpt-3.5-turbo";
toModelName0[ name_String ] := StringReplace[ name, "gpt"~~n:DigitCharacter :> "gpt-"<>n ];
toModelName0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*snapshotModelQ*)
snapshotModelQ // beginDefinition;
snapshotModelQ[ model_ ] := snapshotModelQ[ model, modelNameData @ model ];
snapshotModelQ[ model_, KeyValuePattern[ "Date" -> date_ ] ] := modelDateSpecQ @ date;
snapshotModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fineTunedModelQ*)
fineTunedModelQ // beginDefinition;
fineTunedModelQ[ model_ ] := fineTunedModelQ[ model, modelNameData @ model ];
fineTunedModelQ[ model_, KeyValuePattern[ "FineTuned" -> bool: True|False ] ] := bool;
fineTunedModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*multimodalModelQ*)
(* FIXME: this should be a queryable property from LLMServices: *)
multimodalModelQ // beginDefinition;

multimodalModelQ[ KeyValuePattern[ "Multimodal" -> multimodal_ ] ] :=
    TrueQ @ multimodal;

multimodalModelQ[ "gpt-4-turbo" ] :=
    True;

multimodalModelQ[ name_String? StringQ ] /; StringStartsQ[ name, "claude-3" ] :=
    True;

multimodalModelQ[ name_String? StringQ ] /; StringStartsQ[ name, "gpt-4o" ] :=
    True;

multimodalModelQ[ name_String? StringQ ] /; StringStartsQ[ name, "gpt-4-turbo-" ] :=
    StringMatchQ[ name, "gpt-4-turbo-"~~DatePattern @ { "Year", "Month", "Day" } ];

multimodalModelQ[ name_String? StringQ ] :=
    StringContainsQ[ toModelName @ name, WordBoundary~~"vision"~~WordBoundary, IgnoreCase -> True ];

multimodalModelQ[ other_ ] :=
    With[ { name = toModelName @ other },
        multimodalModelQ @ name /; StringQ @ name
    ];

multimodalModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelNameData*)
modelNameData // beginDefinition;

modelNameData[ data: KeyValuePattern @ {
    "Name"         -> _String,
    "BaseName"     -> _String,
    "Date"         -> _? modelDateSpecQ | None,
    "Preview"      -> True|False,
    "FineTuned"    -> True|False,
    "FineTuneName" -> _String|None,
    "Organization" -> _String|None,
    "ID"           -> _String|None
} ] := modelNameData[ data ] = KeySort @ data;

modelNameData[ as: KeyValuePattern[ "Name" -> name_String ] ] :=
    <| modelNameData @ name, DeleteCases[ as, $$unspecified|None ] |>;

modelNameData[ model0_ ] := Enclose[
    Module[ { model, defaults, data },

        model = ConfirmBy[ toModelName @ model0, StringQ, "Model" ];

        defaults = <|
            "Name"         -> model,
            "Date"         -> None,
            "Preview"      -> False,
            "FineTuned"    -> False,
            "FineTuneName" -> None,
            "Organization" -> None,
            "ID"           -> None
        |>;

        data = ConfirmBy[
            If[ StringMatchQ[ model, "ft:" ~~ __ ~~ ":" ~~ __ ],
                fineTunedModelNameData @ model,
                modelNameData0 @ model
            ],
            AssociationQ,
            "Data"
        ];

        data = <| defaults, data |>;
        data[ "DisplayName" ] = ConfirmBy[ createModelDisplayName @ data, StringQ, "DisplayName" ];
        data //= KeySort;

        modelNameData[ model0 ] = ConfirmBy[ data, AssociationQ, "FullData" ]
    ],
    throwInternalFailure
];

modelNameData // endDefinition;


modelNameData0 // beginDefinition;

modelNameData0[ model_String ] :=
    modelNameData0 @ StringSplit[ model, "-"|" " ]

modelNameData0[ { "gpt", rest___ } ] :=
    modelNameData0 @ { "GPT", rest };

modelNameData0[ { before__, s_String } ] :=
    With[ { date = modelDate @ s },
        <| "Date" -> date, modelNameData0 @ { before } |> /; modelDateSpecQ @ date
    ];

modelNameData0[ { before__, y_String, m_String, d_String } ] :=
    With[ { date = StringRiffle[ { y, m, d }, "-" ] },
        <| "Date" -> DateObject @ date, modelNameData0 @ { before } |> /;
            StringMatchQ[ date, DatePattern @ { "Year", "Month", "Day" } ]
    ];

modelNameData0[ { before__, "preview" } ] :=
    <| "Preview" -> True, modelNameData0 @ { before } |>;

modelNameData0[ { before__, s_String, "vision" } ] :=
    With[ { date = modelDate @ s },
        <| "Date" -> date, modelNameData0 @ { before, "vision" } |> /; modelDateSpecQ @ date
    ];

modelNameData0[ { "GPT", version_String, rest___ } ] /; StringStartsQ[ version, DigitCharacter.. ] :=
    modelNameData0 @ { "GPT-"<>version, rest };

(* cSpell: ignore omni *)
modelNameData0[ { "GPT-4o", rest___ } ] :=
    modelNameData0 @ { "GPT-4", "Omni", rest };

modelNameData0[ parts: { __String } ] :=
	<| "BaseName" -> StringRiffle @ Capitalize @ parts |>;

modelNameData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelDateSpecQ*)
modelDateSpecQ // beginDefinition;
modelDateSpecQ[ date_DateObject ] := DateObjectQ @ date;
modelDateSpecQ[ "Latest" ] := True;
modelDateSpecQ[ _ ] := False
modelDateSpecQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createModelDisplayName*)
createModelDisplayName // beginDefinition;

createModelDisplayName[ KeyValuePattern @ {
    "BaseName"     -> base_String,
    "Date"         -> date0_,
    "Preview"      -> preview0_,
    "Organization" -> org0_,
    "FineTuneName" -> name0_,
    "ID"           -> id0_
} ] :=
    Module[ { date, preview, id, org, ftName, ftID },

        date    = Replace[ modelDateString @ date0, Except[ _String? StringQ ] -> Nothing ];
        preview = If[ TrueQ @ preview0, "(Preview)", Nothing ];
        id      = If[ StringQ @ id0 && id0 =!= "", id0, Nothing ];
        org     = If[ StringQ @ org0 && ! MatchQ[ org0, ""|"personal" ], org0, Nothing ];
        ftName  = If[ StringQ @ name0 && name0 =!= "", name0, Nothing ];

        ftID = Which[
            StringQ @ ftName && StringQ @ org, "(" <> StringRiffle[ { org, ftName }, ":" ] <> ")",
            StringQ @ id || StringQ @ org, "(" <> StringRiffle[ { org, ftName, id }, ":" ] <> ")",
            True, Nothing
        ];

        If[ StringQ @ ftID, date = Nothing ];

        StringReplace[
            StringRiffle[ { base, date, preview, ftID }, " " ],
            {
                ") (Preview)" -> " Preview)",
                ") (" -> ", "
            }
        ]
    ];

createModelDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*modelDateString*)
modelDateString // beginDefinition;
modelDateString[ None ] := None;
modelDateString[ "Latest" ] := "(Latest)";
modelDateString[ date_DateObject ] := modelDateString[ date, Quiet @ DateString[ date, "LocaleDateShort" ] ];
modelDateString[ date_DateObject, string_String ] := "(" <> string <> ")";
modelDateString[ date_DateObject, _ ] := With[ { s = DateString @ date }, modelDateString[ date, s ] /; StringQ @ s ];
modelDateString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fineTunedModelNameData*)
fineTunedModelNameData // beginDefinition;

fineTunedModelNameData[ name_String ] :=
    fineTunedModelNameData @ StringSplit[ name, ":" ];

fineTunedModelNameData[ { "ft", model_, org_, name_, id_ } ] := <|
    modelNameData0 @ model,
    "Organization" -> org,
    "ID"           -> id,
    "FineTuneName" -> name,
    "FineTuned"    -> True
|>;

fineTunedModelNameData[ { "ft", rest__String } ] :=
    fineTunedModelNameData @ { rest };

fineTunedModelNameData[ other: { __String } ] := <|
    modelNameData0 @ StringRiffle[ other, ":" ],
    "FineTuned" -> True
|>;

fineTunedModelNameData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelDisplayName*)
modelDisplayName // beginDefinition;
modelDisplayName[ model_ ] := modelDisplayName[ model, modelNameData @ model ];
modelDisplayName[ model_, KeyValuePattern[ "DisplayName" -> name_String ] ] := name;
modelDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelDate*)
modelDate // beginDefinition;

modelDate[ KeyValuePattern[ "Date" -> date_? modelDateSpecQ ] ] :=
    date;

modelDate[ KeyValuePattern[ "Name" -> name_String ] ] :=
    modelDate @ name;

modelDate[ model_String ] := modelDate[ model ] =
    modelDate @ StringSplit[ model, "-"|" " ];

modelDate[ { ___, "latest" } ] :=
    "Latest";

(* Hack for OpenAI's poor choice of 4 digit dates: *)
modelDate[ { ___, "0125" } ] :=
    DateObject @ { 2024, 1, 25 };

modelDate[ { ___, date_String } ] /; StringMatchQ[ date, Repeated[ DigitCharacter, { 4 } ] ] :=
    DateObject @ Flatten @ { 2023, ToExpression @ StringPartition[ date, 2 ] };

modelDate[ { ___, date_String } ] /; StringMatchQ[ date, Repeated[ DigitCharacter, { 8 } ] ] :=
    DateObject @ StringInsert[ date, "-", { 5, 7 } ];

modelDate[ { ___, y_String, m_String, d_String } ] :=
    With[ { date = StringRiffle[ { y, m, d }, "-" ] },
        DateObject @ StringRiffle[ { y, m, d }, "-" ] /; StringMatchQ[ date, DatePattern @ { "Year", "Month", "Day" } ]
    ];

modelDate[ { ___String } ] :=
    None;

modelDate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fineTunedModelName*)
fineTunedModelName // beginDefinition;

fineTunedModelName[ name_String ] :=
    fineTunedModelName @ StringSplit[ name, ":" ];

fineTunedModelName[ { "ft", rest__ } ] :=
    fineTunedModelName @ { rest };

fineTunedModelName[ { model_String, id__String } ] :=
    StringJoin[
        StringDelete[ modelDisplayName @ model, " ("~~__~~")"~~EndOfString ],
        " (",
        Replace[ { id }, "" -> "::", { 1 } ],
        ")"
    ];

fineTunedModelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelIcon*)
modelIcon // beginDefinition;

modelIcon[ KeyValuePattern[ "Icon" -> icon_ ] ] :=
    icon;

modelIcon[ KeyValuePattern @ { "Name" -> name_String, "Service" -> service_String } ] :=
    Replace[ modelIcon @ name, $defaultModelIcon :> serviceIcon @ service ];

modelIcon[ KeyValuePattern[ "Name" -> name_String ] ] :=
    modelIcon @ name;

modelIcon[ name0_String ] :=
    With[ { name = toModelName @ name0 }, modelIcon @ name /; name =!= name0 ];

modelIcon[ name_String ] /; StringStartsQ[ name, "ft:" ] :=
    modelIcon @ StringDelete[ name, StartOfString~~"ft:" ];

modelIcon[ gpt_String ] /; StringStartsQ[ gpt, "gpt-3.5" ] :=
    RawBoxes @ TemplateBox[ { }, "ModelGPT35" ];

modelIcon[ gpt_String ] /; StringStartsQ[ gpt, "gpt-4" ] :=
    RawBoxes @ TemplateBox[ { }, "ModelGPT4" ];

modelIcon[ name_String ] :=
    $defaultModelIcon;

modelIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*standardizeModelData*)
standardizeModelData // beginDefinition;

standardizeModelData[ list_List ] :=
    Flatten[ standardizeModelData /@ list ];

standardizeModelData[ name_String ] := standardizeModelData[ name ] =
    standardizeModelData @ <| "Name" -> name |>;

standardizeModelData[ model: KeyValuePattern @ { } ] :=
    standardizeModelData[ model ] = KeySort @ <|
        modelNameData @ model,
        "Date"        -> modelDate @ model,
        "DisplayName" -> modelDisplayName @ model,
        "FineTuned"   -> fineTunedModelQ @ model,
        "Icon"        -> modelIcon @ model,
        "Multimodal"  -> multimodalModelQ @ model,
        "Name"        -> modelName @ model,
        "Snapshot"    -> snapshotModelQ @ model,
        model
    |>;

standardizeModelData[ service_String, models_List ] :=
    standardizeModelData[ service, # ] & /@ models;

standardizeModelData[ service_String, model_String ] :=
    standardizeModelData @ <| "Service" -> service, "Name" -> model |>;

standardizeModelData[ service_String, model_ ] :=
    With[ { as = standardizeModelData @ model },
        (standardizeModelData[ service, model ] = <| "Service" -> service, as |>) /; AssociationQ @ as
    ];

standardizeModelData[ KeyValuePattern[ "Service" -> service_String ], model_ ] :=
    standardizeModelData[ service, model ];

standardizeModelData[ $$unspecified ] :=
    With[ { model = $DefaultModel },
        standardizeModelData @ model /; MatchQ[ model, Except[ $$unspecified ] ]
    ];

standardizeModelData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chooseDefaultModelName*)
(*
    Choose a default initial model according to the following rules:
        1. If the service name is the same as the one in $DefaultModel, use the model name in $DefaultModel.
        2. If the registered service specifies a "DefaultModel" property, we'll use that.
        3. If the model list is already cached for the service, we'll use the first model in that list.
        4. Otherwise, give Automatic to indicate a model name that must be resolved later.
*)
chooseDefaultModelName // beginDefinition;
chooseDefaultModelName[ service_String ] /; service === $DefaultModel[ "Service" ] := $DefaultModel[ "Name" ];
chooseDefaultModelName[ service_String ] := chooseDefaultModelName @ $availableServices @ service;
chooseDefaultModelName[ KeyValuePattern[ "DefaultModel" -> model_ ] ] := toModelName @ model;
chooseDefaultModelName[ KeyValuePattern[ "CachedModels" -> models_List ] ] := chooseDefaultModelName @ models;
chooseDefaultModelName[ { model_, ___ } ] := toModelName @ model;
chooseDefaultModelName[ service_ ] := Automatic;
chooseDefaultModelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveFullModelSpec*)
resolveFullModelSpec // beginDefinition;

resolveFullModelSpec[ settings: KeyValuePattern[ "Model" -> model_ ] ] :=
    resolveFullModelSpec @ model;

resolveFullModelSpec[ { service_String, Automatic } ] :=
    resolveFullModelSpec @ <| "Service" -> service, "Name" -> Automatic |>;

resolveFullModelSpec[ model: KeyValuePattern @ { "Service" -> service_String, "Name" -> Automatic } ] := Enclose[
    Catch @ Module[ { default, models, name },
        default = ConfirmMatch[ chooseDefaultModelName @ service, Automatic | _String, "Default" ];
        If[ StringQ @ default, Throw @ standardizeModelData @ <| model, "Name" -> default |> ];
        models = ConfirmMatch[ getServiceModelList @ service, _List | Missing[ "NotConnected" ], "Models" ];
        If[ MissingQ @ models, throwTop @ $Canceled ];
        name = ConfirmBy[ chooseDefaultModelName @ models, StringQ, "ResolvedName" ];
        standardizeModelData @ <| model, "Name" -> name |>
    ],
    throwInternalFailure
];

resolveFullModelSpec[ model_ ] :=
    With[ { spec = standardizeModelData @ model },
        spec /; AssociationQ @ spec
    ];

resolveFullModelSpec // endDefinition;

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

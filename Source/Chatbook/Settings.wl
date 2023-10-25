(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Settings`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `$defaultChatSettings;
    `currentChatSettings;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$defaultChatSettings = <|
    "Assistance"               -> Automatic,
    "AutoFormat"               -> True,
    "BasePrompt"               -> Automatic,
    "CellToMessageFunction"    -> CellToChatMessage,
    "ChatContextPreprompt"     -> Automatic,
    "ChatDrivenNotebook"       -> False,
    "ChatFormattingFunction"   -> FormatChatOutput,
    "ChatHistoryLength"        -> 25,
    "DynamicAutoFormat"        -> Automatic,
    "EnableChatGroupSettings"  -> False,
    "EnableLLMServices"        -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "FrequencyPenalty"         -> 0.1,
    "HandlerFunctions"         :> $DefaultChatHandlerFunctions,
    "HandlerFunctionsKeys"     -> Automatic,
    "IncludeHistory"           -> Automatic,
    "LLMEvaluator"             -> "CodeAssistant",
    "MaxTokens"                -> Automatic,
    "MergeMessages"            -> True,
    "Model"                    :> $DefaultModel,
    "NotebookWriteMethod"      -> Automatic,
    "OpenAIKey"                -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "PresencePenalty"          -> 0.1,
    "ProcessingFunctions"      :> $DefaultChatProcessingFunctions,
    "ShowMinimized"            -> Automatic,
    "StreamingOutputMethod"    -> Automatic,
    "Temperature"              -> 0.7,
    "ToolOptions"              :> $DefaultToolOptions,
    "Tools"                    -> Automatic,
    "ToolsEnabled"             -> Automatic,
    "TopP"                     -> 1,
    "TrackScrollingWhenPlaced" -> Automatic
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$feObj = _FrontEndObject | $FrontEndSession | _NotebookObject | _CellObject | _BoxObject;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Defaults*)
$ChatPost      = None;
$ChatPre       = None;
$DefaultModel := If[ $VersionNumber >= 13.3, "gpt-4", "gpt-3.5-turbo" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Handler Functions*)
$DefaultChatHandlerFunctions = <|
    "ChatPost" :> $ChatPost,
    "ChatPre"  :> $ChatPre
|>;

$DefaultChatHandlerFunctions // Protect;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Processing Functions*)
$DefaultChatProcessingFunctions = <|
    "CellToMessage"    -> CellToChatMessage, (* TODO: hook up to applyProcessingFunction *)
    "ChatMessages"     -> Identity, (* TODO *)
    "ChatSubmit"       -> Automatic,
    "OutputFormatting" -> FormatChatOutput (* TODO: hook up to applyProcessingFunction *)
|>;

$DefaultChatProcessingFunctions // Protect;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentChatSettings*)
GeneralUtilities`SetUsage[ CurrentChatSettings, "\
CurrentChatSettings[obj$, \"key$\"] gives the current chat settings for the CellObject or NotebookObject obj$ for the specified key.
CurrentChatSettings[obj$] gives all current chat settings for obj$.
CurrentChatSettings[] is equivalent to CurrentChatSettings[EvaluationCell[]].
CurrentChatSettings[\"key$\"] is equivalent to CurrentChatSettings[EvaluationCell[], \"key$\"].\
" ];

CurrentChatSettings[ ] := catchMine @
    If[ TrueQ @ $Notebooks,
        CurrentChatSettings @ $currentEvaluationObject,
        $defaultChatSettings
    ];

CurrentChatSettings[ key_String ] := catchMine @
    If[ TrueQ @ $Notebooks,
        CurrentChatSettings[ $currentEvaluationObject, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ cell_CellObject ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings @ parent,
            currentChatSettings @ cell
        ]
    ];

CurrentChatSettings[ cell_CellObject, key_String ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings[ parent, key ],
            currentChatSettings[ cell, key ]
        ]
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings @ obj,
        $defaultChatSettings
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings[ obj, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", CurrentChatSettings, HoldForm @ CurrentChatSettings @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentChatSettings*)
currentChatSettings // beginDefinition;

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := (
    verifyInheritance @ obj;
    currentChatSettings0 @ obj
);

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := (
    verifyInheritance @ obj;
    currentChatSettings0[ obj, key ]
);

currentChatSettings[ cell0_CellObject ] := Catch @ Enclose[
    Module[ { cell, cellInfo, styles, nbo, delimiter, settings },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0 @ cell ];

        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo ], _CellObject|_Missing, "Delimiter" ];

        settings = Select[
            Map[ Association,
                 Flatten @ {
                    AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ],
                    CurrentValue[ DeleteMissing @ { delimiter, cell }, { TaggingRules, "ChatNotebookSettings" } ]
                 }
            ],
            AssociationQ
        ];

        ConfirmBy[ mergeChatSettings @ Flatten @ { $defaultChatSettings, settings }, AssociationQ, "CombinedSettings" ]
    ],
    throwInternalFailure[ currentChatSettings @ cell0, ## ] &
];

currentChatSettings[ cell0_CellObject, key_String ] := Catch @ Enclose[
    Module[ { cell, cellInfo, styles, nbo, cells, delimiter, values },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0[ cell, key ] ];

        nbo   = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];
        cells = ConfirmMatch[ Cells @ nbo, { __CellObject }, "ChatCells" ];

        (* There are apparently temporary mystery cells that get created that aren't in the root cell list which are
           then immediately removed. These inherit the style specified by `DefaultNewCellStyle`. In chat-driven
           notebooks, this is set to "ChatInput", which has a dynamic cell dingbat that needs to resolve
           `currentChatSettings`. In this case, we have special behavior here to prevent a failure. Since that new
           temporary cell doesn't get displayed anyway, we don't need to actually resolve the chat settings for it,
           so we just return a default value instead. Yes, this is an ugly hack.
        *)
        If[ And[ MemberQ[ styles, $$chatInputStyle ], (*It's a "ChatInput" cell*)
                 ! MemberQ[ cells, cell ], (*It's not in the list of cells*)
                 MatchQ[ CurrentValue[ nbo, DefaultNewCellStyle ], $$chatInputStyle ] (*Due to DefaultNewCellStyle*)
            ],
            Throw @ Lookup[ $defaultChatSettings, key, Inherited ]
        ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo, cells ], _CellObject|_Missing, "Delimiter" ];

        values = CurrentValue[ DeleteMissing @ { cell, delimiter }, { TaggingRules, "ChatNotebookSettings", key } ];

        (* TODO: this should also use `mergeChatSettings` in case the values are associations *)
        FirstCase[
            values,
            Except[ Inherited ],
            Replace[
                AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", key } ],
                Inherited :> Lookup[ $defaultChatSettings, key, Inherited ]
            ]
        ]
    ],
    throwInternalFailure[ currentChatSettings[ cell0, key ], ## ] &
];

currentChatSettings // endDefinition;


currentChatSettings0 // beginDefinition;

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession ] :=
    Association[
        $defaultChatSettings,
        Replace[
            Association @ AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] :> <| |>
        ]
    ];

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := Replace[
    AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", key } ],
    Inherited :> Lookup[ $defaultChatSettings, key, Inherited ]
];

currentChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeChatSettings*)
mergeChatSettings // beginDefinition;
mergeChatSettings[ a_List ] := mergeChatSettings0 @ a //. DownValues @ mergeChatSettings0;
mergeChatSettings // endDefinition;

mergeChatSettings0 // beginDefinition;
mergeChatSettings0[ { a___, Inherited.., b___ } ] := mergeChatSettings0 @ { a, b };
mergeChatSettings0[ { a_? AssociationQ, b__? AssociationQ } ] := DeleteMissing @ Merge[ { a, b }, mergeChatSettings0 ];
mergeChatSettings0[ { a___, Except[ _? AssociationQ ].., b__? AssociationQ } ] := mergeChatSettings0 @ { a, b };
mergeChatSettings0[ { __, e: Except[ _? AssociationQ ] } ] := e;
mergeChatSettings0[ { e_ } ] := e;
mergeChatSettings0[ { } ] := Missing[ ];
mergeChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPrecedingDelimiter*)
getPrecedingDelimiter // beginDefinition;

getPrecedingDelimiter[ cell_CellObject ] :=
    getPrecedingDelimiter[ cell, parentNotebook @ cell ];

getPrecedingDelimiter[ cell_CellObject, nbo_NotebookObject ] :=
    getPrecedingDelimiter[ cell, nbo, Cells @ nbo ];

getPrecedingDelimiter[ cell_CellObject, nbo_, { before0___CellObject, cell_, ___ } ] :=
    Module[ { before, delimiterTest, pos },
        before = Reverse @ { before0 };
        delimiterTest = AbsoluteCurrentValue[ before, { TaggingRules, "ChatNotebookSettings", "ChatDelimiter" } ];
        pos = FirstPosition[ delimiterTest, True ];
        If[ MissingQ @ pos, Missing[ "NotAvailable" ], Extract[ before, pos ] ]
    ];

getPrecedingDelimiter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$currentEvaluationObject*)
$currentEvaluationObject := $FrontEndSession;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*verifyInheritance*)
verifyInheritance // beginDefinition;
verifyInheritance[ obj: $$feObj ] /; $cloudNotebooks := True;
verifyInheritance[ obj: $$feObj? inheritingQ ] := True;
verifyInheritance[ obj: $$feObj ] := With[ { verified = verifyInheritance0 @ obj }, True /; inheritingQ @ obj ];
verifyInheritance // endDefinition;


verifyInheritance0 // beginDefinition;

(* Repair tagging rules at top-level and set the inheritance flag: *)
verifyInheritance0[ fe_FrontEndObject ] := Enclose[
    Module[ { tags },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ fe, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        CurrentValue[ fe, TaggingRules ] = tags;
        CurrentValue[ fe, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ] = True;

        ConfirmBy[ CurrentValue[ fe, TaggingRules ], AssociationQ, "Verify" ]
    ],
    throwInternalFailure[ verifyInheritance0 @ fe, ## ] &
];

(* Otherwise, recurse upwards repairing tagging rules: *)
verifyInheritance0[ obj: Except[ _FrontEndObject, $$feObj ] ] :=
    Module[ { parent, tags },
        parent = feParentObject @ obj;
        tags   = verifyInheritance0 @ parent;
        repairTaggingRules[ obj, tags ]
    ];

verifyInheritance0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inheritingQ*)
inheritingQ // beginDefinition;

inheritingQ[ obj: $$feObj ] :=
    TrueQ @ Replace[
        AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ],
        $Failed -> True
    ];

inheritingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*repairTaggingRules*)
repairTaggingRules // beginDefinition;

repairTaggingRules[ box_BoxObject, parentTags_Association? AssociationQ ] := parentTags;

repairTaggingRules[ obj: $$feObj, parentTags_Association? AssociationQ ] := Enclose[
    Module[ { tags, keep },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ obj, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        keep = ConfirmMatch[
            associationComplement[ tags, parentTags ],
            _? AssociationQ | Inherited,
            "Complement"
        ];

        If[ keep[ "ChatNotebookSettings", "InheritanceTest" ],
            keep[ "ChatNotebookSettings", "InheritanceTest" ] =.
        ];

        If[ keep === <| |>,
            CurrentValue[ obj, TaggingRules ] = Inherited,
            CurrentValue[ obj, TaggingRules ] = keep
        ]
    ],
    throwInternalFailure[ repairTaggingRules[ obj, parentTags ], ## ] &
];

repairTaggingRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trToAssociations*)
trToAssociations // beginDefinition;
trToAssociations[ expr_ ] := Replace[ trToAssociations0 @ expr, { } | <| |> -> Inherited ];
trToAssociations // endDefinition;

trToAssociations0 // beginDefinition;

trToAssociations0[ as_Association? AssociationQ ] :=
    Replace[
        DeleteCases[ trToAssociations /@ as /. HoldPattern @ trToAssociations[ expr_ ] :> expr, <| |> | Inherited ],
        <| |> -> Inherited
    ];

trToAssociations0[ { rules: (Rule|RuleDelayed)[ _, _ ].. } ] :=
    trToAssociations0 @ Association @ rules;

trToAssociations0[ expr_ ] :=
    expr;

trToAssociations0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*associationComplement*)
associationComplement // beginDefinition;

associationComplement[ as1_? AssociationQ, as2_? AssociationQ ] :=
    Module[ { complement, common },
        complement = Complement[ as1, as2 ];
        common     = Intersection[ Keys @ complement, Keys @ as2 ];
        Scan[ Function[ complement[ # ] = associationComplement[ as1[ # ], as2[ # ] ] ], common ];
        complement
    ];

associationComplement[ as1: { (Rule|RuleDelayed)[ _, _ ]... }, as2_ ] :=
    associationComplement[ Association @ as1, as2 ];

associationComplement[ as1_, as2: { (Rule|RuleDelayed)[ _, _ ]... } ] :=
    associationComplement[ as1, Association @ as2 ];

associationComplement[ as_, _ ] := as;

associationComplement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
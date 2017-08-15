module TypeScript.Parser exposing (..)

import Ast
import Ast.Statement exposing (..)
import Dict
import Result.Extra
import TypeScript.Data.Aliases exposing (Aliases)
import TypeScript.Data.Port as Port exposing (Port(Port))
import TypeScript.Data.Program exposing (Main)


extractPort : Ast.Statement.Statement -> Maybe Port
extractPort statement =
    case statement of
        PortTypeDeclaration outboundPortName (TypeApplication outboundPortType (TypeConstructor [ "Cmd" ] [ TypeVariable _ ])) ->
            Port outboundPortName Port.Outbound outboundPortType |> Just

        PortTypeDeclaration inboundPortName (TypeApplication (TypeApplication inboundPortType (TypeVariable _)) (TypeConstructor [ "Sub" ] [ TypeVariable _ ])) ->
            Port inboundPortName Port.Inbound inboundPortType |> Just

        _ ->
            Nothing


toProgram : List (List Ast.Statement.Statement) -> TypeScript.Data.Program.Program
toProgram statements =
    let
        ports =
            List.filterMap extractPort flatStatements

        flagsType =
            statements
                |> List.filterMap extractMain
                |> List.head

        aliases =
            extractAliases flatStatements

        flatStatements =
            List.concat statements
    in
    TypeScript.Data.Program.ElmProgram flagsType aliases ports


extractMain : List Ast.Statement.Statement -> Maybe Main
extractMain statements =
    let
        main =
            statements
                |> List.filterMap (programFlagType moduleName)
                |> List.head

        moduleName =
            extractModuleName statements
    in
    main


extractModuleName : List Ast.Statement.Statement -> List String
extractModuleName statements =
    statements
        |> List.filterMap moduleDeclaration
        |> List.head
        |> Maybe.withDefault []


moduleDeclaration : Ast.Statement.Statement -> Maybe (List String)
moduleDeclaration statement =
    case statement of
        ModuleDeclaration moduleName _ ->
            Just moduleName

        PortModuleDeclaration moduleName _ ->
            Just moduleName

        EffectModuleDeclaration moduleName _ _ ->
            Just moduleName

        _ ->
            Nothing


extractAliases : List Ast.Statement.Statement -> Aliases
extractAliases statements =
    statements
        |> List.filterMap aliasOrNothing
        |> Dict.fromList


aliasOrNothing : Ast.Statement.Statement -> Maybe ( List String, Ast.Statement.Type )
aliasOrNothing statement =
    case statement of
        TypeAliasDeclaration (TypeConstructor aliasName []) aliasType ->
            Just ( aliasName, aliasType )

        _ ->
            Nothing


programFlagType : List String -> Ast.Statement.Statement -> Maybe Main
programFlagType moduleName statement =
    case statement of
        FunctionTypeDeclaration "main" (TypeConstructor [ "Program" ] (flagsType :: _)) ->
            case flagsType of
                TypeConstructor [ "Never" ] [] ->
                    Just { moduleName = moduleName, flagsType = Nothing }

                _ ->
                    Just { moduleName = moduleName, flagsType = Just flagsType }

        _ ->
            Nothing


parseSingle : String -> Result String TypeScript.Data.Program.Program
parseSingle ipcFileAsString =
    parse [ ipcFileAsString ]


parse : List String -> Result String TypeScript.Data.Program.Program
parse ipcFilesAsStrings =
    let
        statements =
            List.map Ast.parse ipcFilesAsStrings
                |> Result.Extra.combine
    in
    case statements of
        Ok fileAsts ->
            fileAsts
                |> List.map (\( _, _, statements ) -> statements)
                |> toProgram
                |> Ok

        err ->
            err |> toString |> Err

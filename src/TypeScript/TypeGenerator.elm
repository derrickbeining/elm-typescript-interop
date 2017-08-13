module TypeScript.TypeGenerator exposing (toTsType)

import Ast.Statement exposing (..)


toTsType : Ast.Statement.Type -> String
toTsType elmType =
    case elmType of
        Ast.Statement.TypeConstructor [ primitiveType ] [] ->
            elmPrimitiveToTs primitiveType

        Ast.Statement.TypeConstructor [ "Maybe" ] [ maybeType ] ->
            toTsType maybeType ++ " | null"

        TypeTuple tupleTypes ->
            "["
                ++ (tupleTypes
                        |> List.map toTsType
                        |> String.join ", "
                   )
                ++ "]"

        TypeConstructor [ "List" ] [ listType ] ->
            listTypeString listType

        TypeConstructor [ "Array", "Array" ] [ arrayType ] ->
            listTypeString arrayType

        TypeConstructor [ "Array" ] [ arrayType ] ->
            listTypeString arrayType

        _ ->
            "Unhandled"


listTypeString : Ast.Statement.Type -> String
listTypeString listType =
    toTsType listType ++ "[]"


elmPrimitiveToTs : String -> String
elmPrimitiveToTs elmPrimitive =
    case elmPrimitive of
        "String" ->
            "string"

        "Int" ->
            "number"

        "Float" ->
            "number"

        "Bool" ->
            "boolean"

        _ ->
            "Unhandled"
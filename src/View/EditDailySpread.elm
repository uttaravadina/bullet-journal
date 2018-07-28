module View.EditDailySpread exposing (..)

import Date exposing (Date)
import Html.Attributes as Html
import Html.Events as Html
import Html exposing (Html, text)
import Material
import Material.Button as Button
import Material.Icon as Icon
import Material.List as Lists
import Material.Options as Options exposing (styled, cs, css, when)
import Material.Toolbar as Toolbar
import Navigation
import Parse
import Private.ObjectId as ObjectId
import Task exposing (Task)
import Type.Bullet as Bullet exposing (Bullet)
import Type.DailySpread as DailySpread exposing (DailySpread)
import Url
import View


type alias Model msg =
    { mdc : Material.Model msg
    , dailySpread : Maybe (Parse.Object DailySpread)
    , error : Maybe Parse.Error
    }


defaultModel : Model msg
defaultModel =
    { mdc = Material.defaultModel
    , dailySpread = Nothing
    , error = Nothing
    }


type Msg msg
    = Mdc (Material.Msg msg)
    | DailySpreadResult (Result Parse.Error (Parse.Object DailySpread))
    | BackClicked


init :
    (Msg msg -> msg)
    -> View.Config msg
    -> Parse.ObjectId DailySpread
    -> Model msg
    -> ( Model msg, Cmd msg )
init lift viewConfig objectId model =
    ( defaultModel
    , Cmd.batch
        [ Material.init (lift << Mdc)
        , Task.attempt (lift << DailySpreadResult)
            (DailySpread.get viewConfig.parse objectId)
        ]
    )


subscriptions : (Msg msg -> msg) -> Model msg -> Sub msg
subscriptions lift model =
    Material.subscriptions (lift << Mdc) model


update :
    (Msg msg -> msg)
    -> View.Config msg
    -> Msg msg
    -> Model msg
    -> ( Model msg, Cmd msg )
update lift viewConfig msg model =
    case msg of
        Mdc msg_ ->
            Material.update (lift << Mdc) msg_ model

        DailySpreadResult (Err err) ->
            ( { model | error = Just err }, Cmd.none )

        DailySpreadResult (Ok dailySpread) ->
            ( { model | dailySpread = Just dailySpread }, Cmd.none )

        BackClicked ->
            ( model
            , Navigation.newUrl (Url.toString Url.Index)
            )


view : (Msg msg -> msg) -> View.Config msg -> Model msg -> Html msg
view lift viewConfig model =
    let
        dailySpread_ =
            model.dailySpread

        dailySpread =
            dailySpread_
                |> Maybe.map
                    DailySpread.fromParseObject
    in
        Html.div
            [ Html.class "edit-daily-spread"
            ]
            [ viewConfig.toolbar
                { title =
                    dailySpread
                        |> Maybe.map DailySpread.title
                        |> Maybe.withDefault ""
                , menuIcon =
                    Icon.view
                        [ Toolbar.menuIcon
                        , Options.onClick (lift BackClicked)
                        ]
                        "arrow_back"
                , additionalSections =
                    []
                }
            ]
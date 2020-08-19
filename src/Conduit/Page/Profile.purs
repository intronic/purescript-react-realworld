module Conduit.Page.Profile (Props, Tab(..), mkProfilePage) where

import Prelude
import Apiary.Route (Route(..)) as Apiary
import Apiary.Types (none) as Apiary
import Conduit.Api.Endpoints (FavoriteArticle, GetProfile, ListArticles, UnfavoriteArticle, UnfollowProfile, FollowProfile)
import Conduit.Api.Utils as Utils
import Conduit.Component.App as App
import Conduit.Component.ArticleList (articleList)
import Conduit.Component.Buttons (followButton)
import Conduit.Component.Pagination (pagination)
import Conduit.Component.Tabs as Tabs
import Conduit.Data.Article (Article, defaultArticlesQuery)
import Conduit.Data.Avatar as Avatar
import Conduit.Data.Profile (Author)
import Conduit.Data.Route (Route(..))
import Conduit.Data.Username (Username)
import Conduit.Data.Username as Username
import Conduit.Env (Env)
import Conduit.Env.Routing (navigate)
import Conduit.Hook.Auth (useAuth)
import Data.Either (Either(..), either)
import Data.Foldable (for_)
import Data.Lens (Traversal', preview, set)
import Data.Lens.Index as LI
import Data.Lens.Record as LR
import Data.Maybe (Maybe(..), maybe)
import Data.Monoid (guard)
import Data.Symbol (SProxy(..))
import Data.Tuple.Nested ((/\))
import Data.Variant as Variant
import Network.RemoteData as RemoteData
import React.Basic.DOM as R
import React.Basic.Events (handler_)
import React.Basic.Hooks as React

type Props
  = { username :: Username
    , tab :: Tab
    }

data Tab
  = Published
  | Favorited

derive instance eqTab :: Eq Tab

data Action
  = Initialize
  | LoadArticles { offset :: Int, limit :: Int }
  | ToggleFavorite Int
  | ToggleFollow

mkProfilePage :: App.Component Env Props
mkProfilePage =
  App.component "ProfilePage" { init, update } \env store props -> React.do
    auth <- useAuth env
    React.useEffect props.username do
      store.dispatch Initialize
      mempty
    React.useEffect (props.username /\ props.tab) do
      store.dispatch $ LoadArticles init.pagination
      mempty
    pure $ render auth store props
  where
  init =
    { selectedTab: Nothing
    , author: RemoteData.NotAsked
    , articles: RemoteData.NotAsked
    , pagination: { offset: 0, limit: 5 }
    }

  update self = case _ of
    Initialize -> do
      self.setState _ { author = RemoteData.Loading }
      res <- Utils.makeRequest (Apiary.Route :: GetProfile) { username: self.props.username } Apiary.none Apiary.none
      case res of
        Left error -> self.setState _ { author = RemoteData.Failure error }
        Right response ->
          response
            # Variant.match
                { ok: \{ profile } -> self.setState _ { author = RemoteData.Success profile }
                , notFound: \_ -> navigate Home
                }
    LoadArticles pagination -> do
      let
        query = case self.props.tab of
          Published ->
            defaultArticlesQuery
              { author = Just self.props.username
              , offset = Just pagination.offset
              , limit = Just pagination.limit
              }
          Favorited ->
            defaultArticlesQuery
              { favorited = Just self.props.username
              , offset = Just pagination.offset
              , limit = Just pagination.limit
              }
      self.setState _ { articles = RemoteData.Loading, pagination = pagination }
      res <- Utils.makeRequest (Apiary.Route :: ListArticles) Apiary.none query Apiary.none
      self.setState _ { articles = res # either RemoteData.Failure (Variant.match { ok: RemoteData.Success }) }
    ToggleFavorite ix ->
      for_ (preview (_articles ix) self.state) \{ slug, favorited } -> do
        res <-
          if favorited then
            Utils.makeSecureRequest (Apiary.Route :: UnfavoriteArticle) { slug } Apiary.none Apiary.none
          else
            Utils.makeSecureRequest (Apiary.Route :: FavoriteArticle) { slug } Apiary.none Apiary.none
        for_ res $ Variant.match { ok: \{ article } -> self.setState $ set (_articles ix) article }
    ToggleFollow ->
      for_ (preview _author self.state) \{ username, following } -> do
        res <-
          if following then
            Utils.makeSecureRequest (Apiary.Route :: UnfollowProfile) { username } Apiary.none Apiary.none
          else
            Utils.makeSecureRequest (Apiary.Route :: FollowProfile) { username } Apiary.none Apiary.none
        for_ res $ Variant.match { ok: \{ profile } -> self.setState $ set _author profile }

  render auth store props =
    guard (not $ RemoteData.isLoading store.state.author) container (userInfo auth store props)
      [ Tabs.tabs
          { className: "articles-toggle"
          , selectedTab: Just props.tab
          , tabs:
              [ { id: Published
                , label: R.text "Published Articles"
                , disabled: false
                , content: tabContent store
                }
              , { id: Favorited
                , label: R.text "Favorited Articles"
                , disabled: false
                , content: tabContent store
                }
              ]
          , onChange:
              case _ of
                Published -> navigate $ Profile props.username
                Favorited -> navigate $ Favorites props.username
          }
      ]

  tabContent store =
    R.div_
      [ articleList
          { articles: store.state.articles <#> _.articles
          , onFavoriteToggle: store.dispatch <<< ToggleFavorite
          }
      , store.state.articles
          # RemoteData.maybe React.empty \{ articlesCount } ->
              pagination
                { offset: store.state.pagination.offset
                , limit: store.state.pagination.limit
                , totalCount: articlesCount
                , onChange: store.dispatch <<< LoadArticles
                , focusWindow: 3
                , marginPages: 1
                }
      ]

  userInfo auth store props =
    R.div
      { className: "user-info"
      , children:
          [ R.div
              { className: "container"
              , children:
                  [ R.div
                      { className: "row"
                      , children:
                          [ R.div
                              { className: "col-xs-12 col-md-10 offset-md-1"
                              , children:
                                  [ R.img
                                      { className: "user-img"
                                      , src: Avatar.toString $ RemoteData.maybe Avatar.blank (Avatar.withDefault <<< _.image) store.state.author
                                      }
                                  , R.h4_ [ R.text $ Username.toString props.username ]
                                  , maybe React.empty (\bio -> R.p_ [ R.text bio ]) (RemoteData.toMaybe store.state.author >>= _.bio)
                                  , if (Just props.username == map _.username auth) then
                                      R.button
                                        { className: "btn btn-sm action-btn btn-outline-secondary"
                                        , onClick: handler_ $ navigate Settings
                                        , children:
                                            [ R.i
                                                { className: "ion-gear-a"
                                                , children: []
                                                }
                                            , R.text $ " Edit Profile Settings"
                                            ]
                                        }
                                    else
                                      followButton
                                        { following: RemoteData.maybe false _.following store.state.author
                                        , username: props.username
                                        , onClick: handler_ $ store.dispatch ToggleFollow
                                        }
                                  ]
                              }
                          ]
                      }
                  ]
              }
          ]
      }

  container header children =
    R.div
      { className: "profile-page"
      , children:
          [ header
          , R.div
              { className: "container"
              , children:
                  [ R.div
                      { className: "row"
                      , children:
                          [ R.div
                              { className: "col-xs-12 col-md-10 offset-md-1"
                              , children
                              }
                          ]
                      }
                  ]
              }
          ]
      }

_articles :: forall err r s. Int -> Traversal' { articles :: RemoteData.RemoteData err { articles :: Array Article | s } | r } Article
_articles i = LR.prop (SProxy :: _ "articles") <<< RemoteData._Success <<< LR.prop (SProxy :: _ "articles") <<< LI.ix i

_author :: forall err r. Traversal' { author :: RemoteData.RemoteData err Author | r } Author
_author = LR.prop (SProxy :: _ "author") <<< RemoteData._Success

{-# LANGUAGE TypeFamilies, MultiParamTypeClasses #-}

module World (
  World,
  Inhabitant(..),
  Computation(..),
  ComputationError(..),
  FuncDef(..),
  evaluate,
  caladan
) where
  
import Ast
import qualified Data.Map as M
import Data.List (intercalate)
import Control.Monad (liftM2, mapM)
import Control.Monad.Error --(Error(..), throwError, MonadError(..))

data FuncDef = FuncDef { args :: [String], body :: Expr } deriving (Eq, Show)

data Inhabitant = Value Float
                | Function FuncDef
  deriving (Eq)

type World = M.Map String Inhabitant

newtype ComputationError = ComputationError { msgOf :: String } deriving (Show, Eq)

data Computation a = Success a | Failure ComputationError deriving (Show, Eq)

instance Functor Computation where
  f `fmap` Success a = Success (f a)
  f `fmap` Failure e = Failure e

instance Monad Computation where
  return x = Success x
  (Failure err) >>= _ = Failure err
  (Success x) >>= f = f x

instance MonadError ComputationError Computation where
  throwError = Failure
  catchError = undefined

instance Error ComputationError where
  noMsg  = ComputationError "What the phukk?"
  strMsg = ComputationError 

instance Show Inhabitant where
  show (Value float) = show float
  show (Function (FuncDef args body)) = "f(" ++ intercalate ", " args ++ ") { " ++ show body ++ " }"

evaluate :: World -> Expr -> Computation Float
evaluate world (Number n) = return n
evaluate world (Binary op a b) = liftM2 (apply op) (evaluate world a) (evaluate world b)
evaluate world (Name name) = maybe err return (value world name)
  where err = throwError (strMsg $ "Undefined variable `" ++ name ++ "'")
evaluate world (Call name exprs) = do
    FuncDef args body <- maybe undefinedFunc return (function world name)
    params <- evaluate world `mapM` exprs
    funcWorld <- bind args params
    evaluate funcWorld body
  where undefinedFunc = throwError (strMsg $ "Undefined function `" ++ name ++ "'")

bind :: [String] -> [Float] -> Computation World
bind names values
  | length names == length values = return $ M.fromList (zip names (map Value values))
  | otherwise                     = throwError (strMsg $ "Supplied arguments " ++ show values ++ " for " ++ show names)

value :: World -> String -> Maybe Float
value world name = do
  Value val <- M.lookup name world
  return val
  
function :: World -> String -> Maybe FuncDef
function world name = do
  Function def <- M.lookup name world
  return def

apply :: BinaryOp -> Float -> Float -> Float
apply Add = (+)
apply Sub = (-)
apply Mul = (*)
apply Div = (/)
apply Exp = (**)

caladan :: World
caladan = M.fromList [
    ("paul", Value 3.14),
    ("jessica", Value 2.71), 
    ("larodi", Function (FuncDef [] (Number 1))),
    ("add", Function (FuncDef ["a", "b"] (Name "a" + Name "b"))),
    ("f", Function (FuncDef ["a"] (Name "a" + Name "a")))
  ]

main = do
  print $ evaluate caladan (1 + 2)
  print $ evaluate caladan (1 + 2 + Name "paul")
  print $ evaluate caladan (1 + 2 + Name "larodi")
  print $ evaluate caladan (Call "foo" [1.4, 2])
  print $ evaluate caladan (Call "add" [Name "jessica", 2])
  print $ evaluate caladan (Call "f" [1])
  print $ evaluate caladan (Call "larodi" [])
  return ()


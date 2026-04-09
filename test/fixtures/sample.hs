{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | A sample Haskell module for testing curry-mode.
module Sample
  ( foo
  , bar
  , Baz(..)
  , MyClass(..)
  ) where

import Data.List (sort, nub)
import qualified Data.Map as Map

-- | A simple function.
foo :: Int -> Int -> Int
foo x y = x + y

-- | A function with guards.
bar :: Int -> String
bar n
  | n < 0     = "negative"
  | n == 0    = "zero"
  | otherwise = "positive"

-- | A data type.
data Baz a
  = Baz1 a
  | Baz2 a a
  | Baz3 { bazField :: a }
  deriving (Show, Eq)

-- | A newtype.
newtype Wrapper a = Wrapper { unWrapper :: a }

-- | A type synonym.
type Name = String

-- | A type class.
class MyClass a where
  myMethod :: a -> String
  myDefault :: a -> Int
  myDefault _ = 0

-- | An instance.
instance MyClass Int where
  myMethod n = show n

-- | A function with case expression.
describe :: Baz a -> String
describe x = case x of
  Baz1 _ -> "one"
  Baz2 _ _ -> "two"
  Baz3 {} -> "three"

-- | A function with do notation.
main :: IO ()
main = do
  let greeting = "Hello"
  putStrLn greeting
  putStrLn $ bar 42

-- | A function with where clause.
compute :: Int -> Int
compute n = result
  where
    result = n * factor
    factor = 2

-- | A function with let/in.
withLet :: Int -> Int
withLet n =
  let x = n + 1
      y = n + 2
  in x * y

-- | Lambda expression.
double :: [Int] -> [Int]
double = map (\x -> x * 2)

-- | List comprehension.
evens :: [Int] -> [Int]
evens xs = [x | x <- xs, even x]

-- | Pattern matching with as-pattern.
firstTwo :: [a] -> Maybe (a, a)
firstTwo xs@(_:_:_) = Just (head xs, xs !! 1)
firstTwo _ = Nothing

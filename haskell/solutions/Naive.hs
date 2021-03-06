import Data.Maybe
import Data.List
import Control.Monad

type Name = String

data Term
  = Var Name             -- Variables
  | Lit Int              -- Literals
  | App Term Term        -- Function application
  | Lam Name Type Term   -- Lambda abstraction
  deriving (Show, Eq, Ord)

data Type = Int | Fun Type Type deriving (Show, Eq, Ord)

type Env = [(String, Term)]

lkup :: Env -> String -> Term
lkup env s = fromMaybe (error ("Unbound variable: " ++ s)) (lookup s env)

-- Evaluate a term given an environment
eval :: Env -> Term -> Term
eval env (Var s) =
  eval env $ lkup env s
eval env (App e1 e2) = case (eval env e1) of
  Lam x _ e -> eval env (subst x e2 e)
  _         -> error $ "Not a function: " ++ show e1
eval env l@(Lam x _ e) = repaint allNames l
eval _ x = x

-- A source of fresh names
allNames :: [String]
allNames = [1..] >>= (`replicateM` ['a'..'z'])

-- `subst v e1 e2` substitutes `e1` for variables named `v` in `e2`
subst :: String -> Term -> Term -> Term
subst v t f@(Var s) = if (v == s) then t else f
subst v t (App e1 e2) = App (subst v t e1) (subst v t e2)
subst v t f@(Lam x tp e) = if (x == v) then f else Lam x tp (subst v t e)
subst _ _ x = x

-- Find all the free variables in a term
freeVars :: [String] -> [String] -> Term -> [String]
freeVars free bound (Var s) =
  if (elem s bound) then s:free else free
freeVars free bound (App e1 e2) =
  freeVars free bound e1 ++ freeVars free bound e2
freeVars free bound (Lam s _ e) =
  freeVars free (s:bound) e
freeVars free bound x = free

-- Give all bound variables fresh names from the given bucket
repaint :: [String] -> Term -> Term
repaint bucket (Lam v t e) = Lam fresh t $ repaint (tail freshBucket) e2
  where fresh = head freshBucket
        freshBucket = bucket \\ freeVars [] [] e
        e2 = subst v (Var fresh) e
repaint bucket (App e1 e2) = App (repaint bucket e1) (repaint bucket e2)
repaint _ x = x

i = Lam "x" Int (Var "x")
k = Lam "x" Int (Lam "y" Int (Var "x"))

capturing = App (App k (Var "y")) (Lit 10)
noncapturing = App (App (Lam "a" Int (Lam "b" Int (Var "a"))) (Var "y")) (Lit 10)

-- Evaluating `pathological` with an environment containing
-- `"y"` bound to `Var "x"` should eval to the value of `"x"` in that
-- environment, not to `Lit 4`.
pathological = App (Lam "x" Int (Var "y")) (Lit 4)

empty = []
wy = [("y", Lit 42)]
ex = [("y", Var "x")]
exy = [("y", Var "x"), ("x", Lit 42)]

-- Typer

type TEnv = [(Name, Type)]

typer :: TEnv -> Term -> Type
typer _ (Lit _) = Int
typer env (Var v) = fromMaybe (error $ "Unbound variable " ++ v) $ lookup v env
typer env (App e1 e2) = let t1 = (typer env e1) in case t1 of
  (Fun ta tr) -> let t2 = typer env e2 in
    if (ta == t2) then tr
    else error $ "Type mismatch. Expected " ++
                 show ta ++ " found " ++ show t2
  _ -> error $ "Not a function type: " ++ show t1
typer env (Lam x t e) = Fun t (typer ((x,t):env) e)


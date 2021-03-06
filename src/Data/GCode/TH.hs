{-# LANGUAGE TemplateHaskell #-}
module Data.GCode.TH where

import Language.Haskell.TH

import qualified Data.Char

-- this walks constructors of a datatype
-- and creates isXYZ checks and CodeMod constructors
-- for example for constructor `Rapid` these two are generated
-- isRapid :: Code -> Bool
-- isRapid x = x `codeIsRS274` Rapid
--
-- rapid :: Code
-- rapid = codeFromName Rapid
genShortcuts :: Name -> Q [Dec]
genShortcuts names = do
  info <- reify names
  case info of
    TyConI (DataD _cxt _name _tyvarbndr _kind constructors _deriv)
      -> do
        a <- mapM genTests constructors
        b <- mapM genConstructors constructors
        return $ a ++ b
    _ -> error "Unexpected reify input for genShortcuts"

  where
    genTests (NormalC name _bangs) = do
      varName <- newName "x"
      let
        funName = mkName $ "is" ++ (nameBase name)

      return $ FunD funName
        [ Clause
           [VarP varName]
           (NormalB (InfixE (Just (VarE varName)) (VarE (mkName "codeIsRS274")) (Just (ConE name))))
           []
        ]
    genTests _ = error "Unexpteced input for genTests"

    genConstructors (NormalC name _bangs) = do
      let
        funName = mkName $ (\(x:rest) -> (Data.Char.toLower x : rest)) (nameBase name)
      return $ FunD funName
        [ Clause
          []
          (NormalB ( (VarE (mkName "codeFromName")) `AppE` (ConE name)) )
          []
        ]
    genConstructors _ = error "Unexpteced input for genConstructors"

-- this walks constructors of a datatype
-- and creates constructors to be used in writer monad
--
-- for example for constructor `Move` these two are generated
-- move' :: Control.Monad.Trans.Writer.Lazy.Writer (Endo Program) ()
-- move' = generateName Move
--
-- and a wariant accepting Code endofunctor so we can do move' and also move (xy 2 3)
-- move :: (Code -> Code) -> Control.Monad.Trans.Writer.Lazy.Writer (Endo Program) ()
-- move fn = generateNameArgs Move fn
--
-- We prefer variant with args as it seems to be more common
-- to have GCodes with arguments than just standalone ones.
genWriterEndos :: Name -> Q [Dec]
genWriterEndos names = do
  info <- reify names
  case info of
    TyConI (DataD _cxt _name _tyvarbndr _kind constructors _deriv)
      -> do
        a <- mapM genConstructors constructors
        b <- mapM genConstructorsArgs constructors
        return $ a ++ b
    _ -> error "Unexpected reify input for genWriterEndos"

  where
    genConstructors (NormalC name _bangs) = do
      let
        funName = mkName $ (\(x:rest) -> (Data.Char.toLower x : rest ++ "'")) (nameBase name)
      return $ FunD funName
        [ Clause
          []
          (NormalB ( (VarE (mkName "generateName")) `AppE` (ConE name)) )
          []
        ]
    genConstructors _ = error "Unexpteced input for genConstructors"

    genConstructorsArgs (NormalC name _bangs) = do
      endoName <- newName "x"
      let
        funName = mkName $ (\(x:rest) -> (Data.Char.toLower x : rest)) (nameBase name)
      return $ FunD funName
        [ Clause
          [VarP endoName]
          (NormalB (((VarE (mkName "generateNameArgs")) `AppE` (ConE name)) `AppE` (VarE endoName)) )
          []
        ]
    genConstructorsArgs _ = error "Unexpteced input for genConstructorArgs"

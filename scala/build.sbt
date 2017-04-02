
import com.typesafe.sbt.SbtStartScript


// lazy val jsproj = (project in file("jsproj")).
//  settings(commonSettings: _*).
//  settings(
//    // Sólo si tiene main, si es solo una librería esto no se pone
//    scalaJSUseMainModuleInitializer := true
//  ).
//  enablePlugins(ScalaJSPlugin)

lazy val commonSettings = Seq(
  scalaVersion := "2.11.8"
) ++ Seq(SbtStartScript.startScriptForClassesSettings: _*)

lazy val bindump = (project in file("bindump")).
  settings(commonSettings: _*)

lazy val codegen = (project in file("codegen")).
  settings(commonSettings: _*).
  dependsOn(sexpr, bindump)

lazy val codegen2 = (project in file("codegen2")).
  settings(commonSettings: _*).
  dependsOn(sexpr, bindump)

lazy val sexpr = (project in file("sexpr")).
  settings(commonSettings: _*)

lazy val lua = (project in file("lua")).
  settings(commonSettings: _*).
  settings(
    libraryDependencies ++= Seq("com.lihaoyi" %% "fastparse" % "0.3.7")
  ).
  dependsOn(codegen)

lazy val cu = (project in file("cu")).
  settings(commonSettings: _*).
  settings(
    libraryDependencies ++= Seq("com.lihaoyi" %% "fastparse" % "0.3.7")
  ).
  dependsOn(codegen2)

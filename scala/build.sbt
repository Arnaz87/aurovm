
import com.typesafe.sbt.SbtStartScript

lazy val commonSettings = Seq(
  scalaVersion := "2.11.8"
)



// JVM Only
lazy val bindump = (project in file("bindump")).
  settings(commonSettings: _*).
  settings(SbtStartScript.startScriptForClassesSettings: _*)
  


lazy val format = (crossProject in file("format")).
  settings(commonSettings: _*).
  settings(
    scalaSource in Compile := baseDirectory.value / "../shared/"
  )
lazy val formatJS = format.js
lazy val formatJVM = format.jvm.dependsOn(bindump)



lazy val cu = (crossProject in file("cu")).
  settings(commonSettings: _*).
  settings(
    scalaSource in Compile := baseDirectory.value / "../shared/",
    libraryDependencies ++= Seq("com.lihaoyi" %%% "fastparse" % "0.3.7")
  ).
  dependsOn(format)
lazy val cuJS = cu.js
lazy val cuJVM = cu.jvm.
  settings(SbtStartScript.startScriptForClassesSettings: _*)



lazy val js = (crossProject in file("js")).
  settings(commonSettings: _*).
  settings(
    scalaSource in Compile := baseDirectory.value / "../shared/"
  ).
  dependsOn(format)
lazy val jsJS = js.js
lazy val jsJVM = js.jvm.dependsOn(cuJVM)



/*lazy val lua = (project in file("lua")).
  settings(commonSettings: _*).
  settings(
    libraryDependencies ++= Seq("com.lihaoyi" %% "fastparse" % "0.3.7")
  ).
  dependsOn(format)*/


// JS Only
lazy val web = (project in file("web")).
  enablePlugins(ScalaJSPlugin).
  settings(commonSettings: _*).
  settings(
    // Sólo si tiene main, si es solo una librería esto no se pone
    //scalaJSUseMainModuleInitializer := true
  ).
  dependsOn(cuJS, jsJS)

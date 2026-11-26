# Make a release of Ladder: an app that other Macs open, in a zip file.
#
#     julia --project=. release.jl             builds build/Ladder-<version>.zip
#     julia --project=. release.jl --publish   then puts it on GitHub as a release
#
# The version comes from the VERSION file. Change it before each release.
#
# A release has two files: the zip file, and latest.txt, which names the version
# and the zip file. Each copy of the app reads latest.txt to see if it's the
# newest version, and updates itself from the zip file if not. update.jl says
# how. The release goes to the GitHub repo that update.jl names as `REPO`, which
# must be public, since the app reads it without an account.
#
# It builds the app, signs it with your Developer ID certificate, and sends it
# to Apple to be notarised. Apple checks it for malware, which takes a few
# minutes. A Mac opens a notarised app without a warning.
#
# Before the first release, give `notarytool` your Apple account once. It keeps
# it in your keychain under the name "kaydown", which was the app's name when
# the first release was made:
#
#     xcrun notarytool store-credentials kaydown --apple-id <your Apple ID> --team-id <your team ID>
#
# It asks for an app-specific password, which you make at account.apple.com
# under Sign-In and Security. With an App Store Connect API key, give it the key
# instead:
#
#     xcrun notarytool store-credentials kaydown --key <path of the .p8 file> --key-id <key ID> --issuer <issuer ID>
#
# These environment variables change what it uses:
#
#   APP_SIGN="Developer ID Application"   the certificate that signs the app
#   NOTARY_PROFILE=kaydown                the name notarytool keeps your account under

using Kip
@use "./app/facts" => Facts
@use "./update" => Update
include("app/build.jl")   # defines `Build` (with `Build.Bundle` and `Build.build_ladder`)

"Run `cmd` in Ladder's folder and give back what it prints"
output(cmd) = readchomp(setenv(cmd, dir=Facts.ROOT))
ok(cmd) = success(pipeline(setenv(cmd, dir=Facts.ROOT), stdout=devnull, stderr=devnull))

"Make a notarised release of Ladder, and with `publish=true` publish it on GitHub"
function release(; publish::Bool=false,
                   profile::AbstractString=get(ENV, "NOTARY_PROFILE", "kaydown"),
                   signer::AbstractString=get(ENV, "APP_SIGN", "Developer ID Application"))
  version = Facts.app_version()
  tag = "v" * version
  # The app compares versions, so the version is written the way Julia writes one
  string(something(tryparse(VersionNumber, version), "")) == version ||
    error("The VERSION file says \"", version, "\". Write the version with three numbers, like 1.2.0.")

  # Find what would stop the release before the build, which takes a few minutes
  ok(`xcrun notarytool history --keychain-profile $profile`) ||
    error("notarytool has no account under the name \"$profile\". See the top of release.jl for how to store one.")

  # The GitHub repo that gets the release. The app looks there for a newer version.
  repo = Update.REPO
  packages = Build.Bundle.find_packages()
  if publish
    (ok(`gh repo view $repo`) && output(`gh repo view $repo --json visibility --jq .visibility`) == "PUBLIC") ||
      error("The app looks for a newer version in the releases of github.com/", repo, ", so that must be a public repo. ",
            "Make it, or name another repo as `REPO` in app/facts.jl.")
    isempty(output(`git status --porcelain`)) || error("Commit your changes first, so the release matches a commit.")
    dirty = Build.Bundle.uncommitted(packages)
    isempty(dirty) || error("Commit the changes in ", join(dirty, ", ", " and "), " first. The app is built from them.")
    isempty(output(`git tag --list $tag`)) || error("There is already a tag $tag. Change the VERSION file.")
    ok(`gh release view $tag --repo $repo`) && error("GitHub already has a release $tag. Change the VERSION file.")
  end

  # Sign it the way Apple needs, and don't mark it as built on this Mac
  built = Build.build_ladder(releasing=true, signer=signer, packages=packages)
  app, version = built.app, built.version

  zip = Facts.zip_file(version)
  pack() = (rm(zip, force=true); run(`ditto -c -k --keepParent $app $zip`))

  pack()
  println("Sending the app to Apple to be notarised. This takes a few minutes.")
  answer = read(`xcrun notarytool submit $zip --keychain-profile $profile --wait`, String)
  println(answer)
  if !occursin("status: Accepted", answer)
    id = match(r"id: ([0-9a-f-]+)", answer)
    id === nothing || run(ignorestatus(`xcrun notarytool log $(id[1]) --keychain-profile $profile`))
    error("Apple didn't notarise the app. Its reasons are above.")
  end
  # Put Apple's ticket in the app, so a Mac that's offline opens it too. Then zip the app again with the ticket in it.
  run(`xcrun stapler staple $app`)
  pack()
  run(`spctl --assess --type execute --verbose $app`)
  # latest.txt names this version and the zip file, for the copies of the app that look for a newer version
  latest = Update.announce(Facts.BUILD_DIR, version, zip,
                           macos=readchomp(`plutil -extract LSMinimumSystemVersion raw $(joinpath(app, "Contents", "Info.plist"))`))
  println("\n", zip, " is ready.")

  if publish
    run(setenv(`git tag $tag`, dir=Facts.ROOT))
    run(setenv(`git push origin $tag`, dir=Facts.ROOT))
    # GitHub writes the notes from the commits when the release is in the repo of the source
    ours = endswith(replace(output(`git remote get-url origin`), r"\.git$" => ""), "/" * repo)
    title = "$(Facts.APP_NAME) $version"
    notes = ours ? `--generate-notes` : `--notes $title`
    # GitHub shows the release only once both files are there, so latest.txt never names a file that isn't
    run(`gh release create $tag $zip $latest --repo $repo --title $title $notes`)
    println("Published ", tag, " on github.com/", repo, ". Each copy of the app gets it within a day.")
  else
    println("Run it again with --publish to put it on GitHub as release ", tag, ".")
  end
  (; app, version, zip, latest)
end

if abspath(PROGRAM_FILE) == @__FILE__
  release(publish="--publish" in ARGS)
end

//
// Copyright (c) 2008-2015 the Urho3D project.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#ifdef URHO3D_ANGELSCRIPT
#include <Urho3D/AngelScript/ScriptFile.h>
#include <Urho3D/AngelScript/Script.h>
#endif
#include <Urho3D/Core/Main.h>
#include <Urho3D/Engine/Engine.h>
#include <Urho3D/IO/FileSystem.h>
#include <Urho3D/IO/Log.h>
#ifdef URHO3D_LUA
#include <Urho3D/LuaScript/LuaScript.h>
#endif
#include <Urho3D/Resource/ResourceCache.h>
#include <Urho3D/Resource/ResourceEvents.h>

#include "Urho3DPlayer.h"

#include <Urho3D/DebugNew.h>

#include <Urho3D/UI/UI.h>
#include <Urho3D/UI/UIEvents.h>
#include <Urho3D/Graphics/Graphics.h>

URHO3D_DEFINE_APPLICATION_MAIN(Urho3DPlayer);

Urho3DPlayer::Urho3DPlayer(Context* context) :
    Application(context)
{
}

void Urho3DPlayer::Setup()
{
    FileSystem* filesystem = GetSubsystem<FileSystem>();

    // Read command line from a file if no arguments given. This is primarily intended for mobile platforms.
    // Note that the command file name uses a hardcoded path that does not utilize the resource system
    // properly (including resource path prefix), as the resource system is not yet initialized at this point
    const String commandFileName = filesystem->GetProgramDir() + "Data/CommandLine.txt";
    if (GetArguments().Empty() && filesystem->FileExists(commandFileName))
    {
        SharedPtr<File> commandFile(new File(context_, commandFileName));
        String commandLine = commandFile->ReadLine();
        commandFile->Close();
        ParseArguments(commandLine, false);
        // Reparse engine startup parameters now
        engineParameters_ = Engine::ParseParameters(GetArguments());
    }

    // Check for script file name
    const Vector<String>& arguments = GetArguments();
    String scriptFileName;
    if (arguments.Size() && arguments[0][0] != '-')
        scriptFileName_ = GetInternalPath(arguments[0]);

    // Show usage if not found
    if (scriptFileName_.Empty())
    {
        ErrorExit("Usage: Urho3DPlayer <scriptfile> [options]\n\n"
            "The script file should implement the function void Start() for initializing the "
            "application and subscribing to all necessary events, such as the frame update.\n"
            #ifndef WIN32
            "\nCommand line options:\n"
            "-x <res>     Horizontal resolution\n"
            "-y <res>     Vertical resolution\n"
            "-m <level>   Enable hardware multisampling\n"
            "-v           Enable vertical sync\n"
            "-t           Enable triple buffering\n"
            "-w           Start in windowed mode\n"
            "-s           Enable resizing when in windowed mode\n"
            "-q           Enable quiet mode which does not log to standard output stream\n"
            "-b <length>  Sound buffer length in milliseconds\n"
            "-r <freq>    Sound mixing frequency in Hz\n"
            "-p <paths>   Resource path(s) to use, separated by semicolons\n"
            "-ap <paths>  Autoload resource path(s) to use, seperated by semicolons\n"
            "-log <level> Change the log level, valid 'level' values are 'debug', 'info', 'warning', 'error'\n"
            "-ds <file>   Dump used shader variations to a file for precaching\n"
            "-mq <level>  Material quality level, default 2 (high)\n"
            "-tq <level>  Texture quality level, default 2 (high)\n"
            "-tf <level>  Texture filter mode, default 2 (trilinear)\n"
            "-af <level>  Texture anisotropy level, default 4. Also sets anisotropic filter mode\n"
            "-gl2         Force OpenGL 2 use even if OpenGL 3 is available\n"
            "-flushgpu    Flush GPU command queue each frame. Effective only on Direct3D\n"
            "-borderless  Borderless window mode\n"
            "-headless    Headless mode. No application window will be created\n"
            "-landscape   Use landscape orientations (iOS only, default)\n"
            "-portrait    Use portrait orientations (iOS only)\n"
            "-prepass     Use light pre-pass rendering\n"
            "-deferred    Use deferred rendering\n"
            "-renderpath <name> Use the named renderpath (must enter full resource name)\n"
            "-lqshadows   Use low-quality (1-sample) shadow filtering\n"
            "-noshadows   Disable shadow rendering\n"
            "-nolimit     Disable frame limiter\n"
            "-nothreads   Disable worker threads\n"
            "-nosound     Disable sound output\n"
            "-noip        Disable sound mixing interpolation\n"
            "-touch       Touch emulation on desktop platform\n"
            #endif
        );
    }
    else
    {
        // Use the script file name as the base name for the log file
        engineParameters_["LogName"] = filesystem->GetAppPreferencesDir("urho3d", "logs") + GetFileNameAndExtension(scriptFileName_) + ".log";
    }

    // Construct a search path to find the resource prefix with two entries:
    // The first entry is an empty path which will be substituted with program/bin directory -- this entry is for binary when it is still in build tree
    // The second entry is a relative path from the installed program/bin directory to the asset directory -- this entry is for binary when it is in the Urho3D SDK installation location
    if (!engineParameters_.Contains("ResourcePrefixPaths"))
        engineParameters_["ResourcePrefixPaths"] = ";../share/Urho3D/Resources";

	engineParameters_["WindowWidth"] = 800;
	engineParameters_["WindowHeight"] = 480;
	engineParameters_["WindowResizable"] = true;
	engineParameters_["WindowTitle"] = "LvL99";
	engineParameters_["FullScreen"] = false;
	engineParameters_["VSync"] = true;
}

void Urho3DPlayer::Start()
{
	if (!engine_->IsHeadless())
	{
		SubscribeToEvent(E_ADDGUITARGETS, URHO3D_HANDLER(Urho3DPlayer, HandleElementAddGuiTargets));
		SubscribeToEvent(E_RESIZED, URHO3D_HANDLER(Urho3DPlayer, HandleElementResize));
	}

    String extension = GetExtension(scriptFileName_);
    if (extension != ".lua" && extension != ".luc")
    {
#ifdef URHO3D_ANGELSCRIPT
        // Instantiate and register the AngelScript subsystem
        context_->RegisterSubsystem(new Script(context_));

        // Hold a shared pointer to the script file to make sure it is not unloaded during runtime
        scriptFile_ = GetSubsystem<ResourceCache>()->GetResource<ScriptFile>(scriptFileName_);

        /// \hack If we are running the editor, also instantiate Lua subsystem to enable editing Lua ScriptInstances
#ifdef URHO3D_LUA
        if (scriptFileName_.Contains("Editor.as", false))
            context_->RegisterSubsystem(new LuaScript(context_));
#endif
        // If script loading is successful, proceed to main loop
        if (scriptFile_ && scriptFile_->Execute("void Start()"))
        {
            // Subscribe to script's reload event to allow live-reload of the application
            SubscribeToEvent(scriptFile_, E_RELOADSTARTED, URHO3D_HANDLER(Urho3DPlayer, HandleScriptReloadStarted));
            SubscribeToEvent(scriptFile_, E_RELOADFINISHED, URHO3D_HANDLER(Urho3DPlayer, HandleScriptReloadFinished));
            SubscribeToEvent(scriptFile_, E_RELOADFAILED, URHO3D_HANDLER(Urho3DPlayer, HandleScriptReloadFailed));
            return;
        }
#else
        ErrorExit("AngelScript is not enabled!");
        return;
#endif
    }
    else
    {
#ifdef URHO3D_LUA
        // Instantiate and register the Lua script subsystem
        LuaScript* luaScript = new LuaScript(context_);
        context_->RegisterSubsystem(luaScript);

        // If script loading is successful, proceed to main loop
        if (luaScript->ExecuteFile(scriptFileName_))
        {
            luaScript->ExecuteFunction("Start");
            return;
        }
#else
        ErrorExit("Lua is not enabled!");
        return;
#endif
    }

    // The script was not successfully loaded. Show the last error message and do not run the main loop
    ErrorExit();
}

void Urho3DPlayer::Stop()
{
#ifdef URHO3D_ANGELSCRIPT
    if (scriptFile_)
    {
        // Execute the optional stop function
        if (scriptFile_->GetFunction("void Stop()"))
            scriptFile_->Execute("void Stop()");
    }
#else
    if (false)
    {
    }
#endif

#ifdef URHO3D_LUA
    else
    {
        LuaScript* luaScript = GetSubsystem<LuaScript>();
        if (luaScript && luaScript->GetFunction("Stop", true))
            luaScript->ExecuteFunction("Stop");
    }
#endif
}

void Urho3DPlayer::HandleScriptReloadStarted(StringHash eventType, VariantMap& eventData)
{
#ifdef URHO3D_ANGELSCRIPT
    if (scriptFile_->GetFunction("void Stop()"))
        scriptFile_->Execute("void Stop()");
#endif
}

void Urho3DPlayer::HandleScriptReloadFinished(StringHash eventType, VariantMap& eventData)
{
#ifdef URHO3D_ANGELSCRIPT
    // Restart the script application after reload
    if (!scriptFile_->Execute("void Start()"))
    {
        scriptFile_.Reset();
        ErrorExit();
    }
#endif
}

void Urho3DPlayer::HandleScriptReloadFailed(StringHash eventType, VariantMap& eventData)
{
#ifdef URHO3D_ANGELSCRIPT
    scriptFile_.Reset();
    ErrorExit();
#endif
}

void Urho3DPlayer::HandleElementResize(StringHash eventType, VariantMap& eventData)
{
	using namespace Resized;

	UIElement* ele = static_cast<UIElement*>(eventData[ElementAdded::P_ELEMENT].GetPtr());

	ElementRecursiveResize(ele);
}

void Urho3DPlayer::ElementRecursiveResize(UIElement* ele)
{
	Vector3 targetRes, targetSize, targetPos;

	targetRes = ele->GetVar("targetRes").GetVector3();
	targetSize = ele->GetVar("targetSize").GetVector3();
	targetPos = ele->GetVar("targetPos").GetVector3();

	if (targetRes != Vector3::ZERO)
	{

		IntVector2 rootExtent;

		rootExtent.x_ = GetSubsystem<Graphics>()->GetWidth();
		rootExtent.y_ = GetSubsystem<Graphics>()->GetHeight();

		IntVector2 scaledExtent;

		scaledExtent.x_ = ( targetSize.x_ *  rootExtent.x_ ) / targetRes.x_;
		scaledExtent.y_ = ( targetSize.y_ *  rootExtent.y_ ) / targetRes.y_;

		ele->SetSize(scaledExtent);

		IntVector2 scaledPosition = IntVector2(
				( targetPos.x_ *  rootExtent.x_ ) / targetRes.x_,
				( targetPos.y_ *  rootExtent.y_ ) / targetRes.y_);

		ele->SetPosition(scaledPosition);

	}

	for (int x = 0; x < ele->GetNumChildren(); x++)
	{
		ElementRecursiveResize(ele->GetChild(x));
	}

}

void Urho3DPlayer::HandleElementAddGuiTargets(StringHash eventType, VariantMap& eventData)
{
	UIElement* ele = static_cast<UIElement*>(eventData[AddGuiTargets::P_ELEMENT].GetPtr());

	RecursiveAddGuiTargets(ele);
}

void Urho3DPlayer::RecursiveAddGuiTargets(UIElement* ele)
{
	Vector3 targetRes, targetSize, targetPos;
	IntVector2 v2;

	targetRes = Vector3(800, 480, 0);
	ele->SetVar("targetRes", targetRes);

	v2 = ele->GetSize();

	if (v2 == IntVector2::ZERO)
	{
		v2 = IntVector2(800, 480);
	}

	targetSize = Vector3(v2.x_, v2.y_, 0.0f);
	ele->SetVar("targetSize", targetSize);

	v2 = ele->GetPosition();
	targetPos = Vector3(v2.x_, v2.y_, 0.0f);
	ele->SetVar("targetPos", targetPos);

	for (int x = 0; x < ele->GetNumChildren(); x++)
	{
		RecursiveAddGuiTargets(ele->GetChild(x));
	}
}

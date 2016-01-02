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

#pragma once

#include <Urho3D/Engine/Application.h>
#include <Urho3D/UI/UI.h>

using namespace Urho3D;

URHO3D_EVENT(E_ADDGUITARGETS, AddGuiTargets)
{
	URHO3D_PARAM(P_ELEMENT, Element);//uielement pointer
}

URHO3D_EVENT(E_GAMEMENUDISPLAY, GameMenuDisplay)
{
	URHO3D_PARAM(P_STATE, State);// bool
}

URHO3D_EVENT(E_GETSELECTEDOBJECTS, GetSelectedObjects)
{

}

URHO3D_EVENT(E_SETSELECTEDOBJECTS, SetSelectedObjects)
{
	URHO3D_PARAM(P_PLAYER, Player);// string
	URHO3D_PARAM(P_FIEND, Fiend);// string
	URHO3D_PARAM(P_LEVEL, Level);// string
}

/// Urho3DPlayer application runs a script specified on the command line.
class Urho3DPlayer : public Application
{
    URHO3D_OBJECT(Urho3DPlayer, Application);

public:
    /// Construct.
    Urho3DPlayer(Context* context);

    /// Setup before engine initialization. Verify that a script file has been specified.
    virtual void Setup();
    /// Setup after engine initialization. Load the script and execute its start function.
    virtual void Start();
    /// Cleanup after the main loop. Run the script's stop function if it exists.
    virtual void Stop();

    void HandleElementAddGuiTargets(StringHash eventType, VariantMap& eventData);
    void HandleElementResize(StringHash eventType, VariantMap& eventData);
    void RecursiveAddGuiTargets(UIElement* ele);
    void ElementRecursiveResize(UIElement* ele);

private:
    /// Handle reload start of the script file.
    void HandleScriptReloadStarted(StringHash eventType, VariantMap& eventData);
    /// Handle reload success of the script file.
    void HandleScriptReloadFinished(StringHash eventType, VariantMap& eventData);
    /// Handle reload failure of the script file.
    void HandleScriptReloadFailed(StringHash eventType, VariantMap& eventData);

    /// Script file name.
    String scriptFileName_;
    
#ifdef URHO3D_ANGELSCRIPT
    /// Script file.
    SharedPtr<ScriptFile> scriptFile_;
#endif
};

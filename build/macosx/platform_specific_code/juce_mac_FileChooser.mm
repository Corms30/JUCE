/*
  ==============================================================================

   This file is part of the JUCE library - "Jules' Utility Class Extensions"
   Copyright 2004-7 by Raw Material Software ltd.

  ------------------------------------------------------------------------------

   JUCE can be redistributed and/or modified under the terms of the
   GNU General Public License, as published by the Free Software Foundation;
   either version 2 of the License, or (at your option) any later version.

   JUCE is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with JUCE; if not, visit www.gnu.org/licenses or write to the
   Free Software Foundation, Inc., 59 Temple Place, Suite 330,
   Boston, MA 02111-1307 USA

  ------------------------------------------------------------------------------

   If you'd like to release a closed-source product which uses JUCE, commercial
   licenses are also available: visit www.rawmaterialsoftware.com/juce for
   more information.

  ==============================================================================
*/

#include "juce_mac_NativeHeaders.h"
#include <fnmatch.h>

BEGIN_JUCE_NAMESPACE
#include "../../../src/juce_appframework/gui/components/filebrowser/juce_FileChooser.h"
END_JUCE_NAMESPACE

static const juce::String nsStringToJuce (NSString* s)
{
    return juce::String::fromUTF8 ((juce::uint8*) [s UTF8String]);
}

static NSString* juceStringToNS (const juce::String& s)
{
    return [NSString stringWithUTF8String: (const char*) s.toUTF8()];
}

//==============================================================================
@interface JuceFileChooserDelegate   : NSObject
{
    juce::StringArray* filters;
}

- (JuceFileChooserDelegate*) initWithFilters: (juce::StringArray*) filters_;
- (void) dealloc;
- (BOOL) panel:(id) sender shouldShowFilename: (NSString*) filename;

@end

@implementation JuceFileChooserDelegate
- (JuceFileChooserDelegate*) initWithFilters: (juce::StringArray*) filters_
{
    [super init];
    filters = filters_;
    return self;
}

- (void) dealloc
{
    delete filters;
    [super dealloc];
}

- (BOOL) panel:(id) sender shouldShowFilename: (NSString*) filename
{
    const char* filenameUTF8 = (const char*) [filename UTF8String];

    for (int i = filters->size(); --i >= 0;)
    {
        const juce::String wildcard ((*filters)[i].toLowerCase());

        if (fnmatch (wildcard.toUTF8(), filenameUTF8, 0) == 0)
            return true;
    }

    return false;
}
@end

BEGIN_JUCE_NAMESPACE


void FileChooser::showPlatformDialog (OwnedArray<File>& results,
                                      const String& title,
                                      const File& currentFileOrDirectory,
                                      const String& filter,
                                      bool selectsDirectory,
                                      bool isSaveDialogue,
                                      bool warnAboutOverwritingExistingFiles,
                                      bool selectMultipleFiles,
                                      FilePreviewComponent* extraInfoComponent)
{
    const AutoPool pool;

    StringArray* filters = new StringArray();
    filters->addTokens (filter.replaceCharacters (T(",:"), T(";;")), T(";"), 0);
    filters->trim();
    filters->removeEmptyStrings();

    JuceFileChooserDelegate* delegate = [[JuceFileChooserDelegate alloc] initWithFilters: filters];
    [delegate autorelease];

    NSSavePanel* panel = isSaveDialogue ? [NSSavePanel savePanel]
                                        : [NSOpenPanel openPanel];

    [panel setTitle: juceStringToNS (title)];

    if (! isSaveDialogue)
    {
        NSOpenPanel* openPanel = (NSOpenPanel*) panel;
        [openPanel setCanChooseDirectories: selectsDirectory];
        [openPanel setCanChooseFiles: ! selectsDirectory];
        [openPanel setAllowsMultipleSelection: selectMultipleFiles];
    }

    [panel setDelegate: delegate];

    NSInteger result = [panel runModalForDirectory: juceStringToNS (currentFileOrDirectory.getParentDirectory().getFullPathName())
                              file: juceStringToNS (currentFileOrDirectory.getFileName())];
    if (result == NSOKButton)
    {
        if (isSaveDialogue)
        {
            results.add (new File (nsStringToJuce ([panel filename])));
        }
        else
        {
            NSOpenPanel* openPanel = (NSOpenPanel*) panel;
            NSArray* urls = [openPanel filenames];
            for (int i = 0; i < [urls count]; ++i)
            {
                NSString* f = [urls objectAtIndex: i];
                results.add (new File (nsStringToJuce (f)));
            }
        }
    }
}

END_JUCE_NAMESPACE

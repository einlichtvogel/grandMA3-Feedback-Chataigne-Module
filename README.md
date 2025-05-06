# grandMA3-Feedback-Chataigne-Module

A Chataigne module to receive feedback from grandMA3 via OSC and an LUA plugin.

## Features

The following feedback via from grandMA3:

- Color Value
- Button State
- Fader Value
- Sequence Name

The feedback is always sent for all executors (Wing 1 - 6 + XKeys) on the current page and for the 'Any Page' executors specified in the grandMA plugin.
Updates for the specified executors are sent for all existing pages.

## Setup

1. Copy the latest version (grandMA3 OSC Feedback - X.X.X.X.xml) [here](https://github.com/einlichtvogel/grandMA3-Feedback-Chataigne-Module/releases/latest) and move it to MALightingTechnology/gma3_libary/datapools/plugins"
2. [Import](https://help.malighting.com/grandMA3/2.2/HTML/plugins.html) the plugin in grandMA3
3. Click on the plugin, select "Settings" and change the settings as needed. The necessary OSC settings are being created automatically. More under [Settings](#grandma3-plugin-settings).
4. In Chataigne, add the grandMA3 module to your project and if needed, check if port "8093" is set as OSC Input.
5. Then, Click on the plugin and select "Start". The plugin will now send updates to Chataigne.

## GrandMA3 Plugin Settings
<img src="docs/images/grandMA_plugin.png" alt="grandMA3 Plugin Settings" width="600"/>

- **Any Page**: The executors that should be sent for all pages. This is useful if you want to have f.e. exec 101 on page 1 and 2, but you want to get feedback no matter which page you currently selected in grandMA3.
- **automaticResendButtons**: If set to true, the plugin will automatically resend the feedback each second.
- **sendColors**: If set to true, the plugin will send the color value of the executor.
- **sendFaders**: If set to true, the plugin will send the fader value of the executor.
- **sendNames**: If set to true, the plugin will send the name from the sequence of the executor.
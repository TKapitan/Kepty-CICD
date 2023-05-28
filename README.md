# CI/CD by Kepty

This repository contains CI/CD scripts for Azure DevOps pipelines. I created this repository in 2019/2020 to learn more about how to use CI/CD scripts for Business Central projects.

Right now, I'm moving my code to a public GitHub repository, but not all files are yet ready to be published.

This repository and scripts are originally based on the old official CI/CD scripts made by Microsoft. [See the original content](https://github.com/microsoft/AL-Go/blob/main/Scenarios/old/CI_CD_Workshop.md#workshop-repositories).

# Disclaimer

This repository is my open source project. Please note that the project is provided "as is" and without any warranty of any kind, either express or implied. By using or accessing this project, you agree that the use of the project is at your own risk.

If you are looking for stable CI/CD solutions for your Business Central projects, I recommend to use one of these solutions

- [AL Ops](https://marketplace.visualstudio.com/items?itemName=Hodor.hodor-alops) for Azure DevOps made by Waldo
- [AL-Go](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/al-go/algo-overview) for GitHub made by Freddy (Microsoft)

These solutions offer many more tools and support probably all processes you can think of for automation.

# Content

- [Supported Scenarios](#supported-scenarios)
- [How to start with this template](#how-to-start-with-this-template)
    - [Update Settings.json](#update-settingsjson)
- [Create a pipeline](#create-a-pipeline)
    - [Azure DevOps Variables](#azure-devops-variables)

## Supported Scenarios

Currently, these scenarios are supported
- Run CI pipeline for Pull Requests
- Run Current, Next-Minor and Next-Major pipelines 
- Bulk update all repositories using the Current pipeline

Scenarios not yet supported
- Publish PTE extension to online BC
- Update app.json version
- Publish artifacts

## How to start with this template

- Copy the .azureDevOps and Scripts folders to your repository folder and include both folders in your workspace.
- Update the *settings.json* file in the Scripts folder (see below for details).
- Push all files from these folders to your Azure DevOps repository.

### Update Settings.json

- Update the following values based on your project requirements
    - **name**
    - **country**, **additionalCountries**
    - **appFolders**, **testFolders**
    - **appSourceCopMandatoryAffixes**, **appSourceCopSupportedCountries**
- To specify when the pipeline should fail
    - **Kepty_failOn**
        - Possible values - warning/error
        - This setting is not really useful for the Current/Next-Major and Next-Minor pipelines. For the CI pipeline, if you use *Error*, the PR merge will be blocked only when there are errors (errors in build or tests). If you use *Warning*, the PR merge will fail for any warnings.
- To use your license file
    - Since v22, the standard Cronus license has permissions for all object IDs and can be used for any pipelines.
    - **Kepty_licenseFileLocation**
- To include preprocessor symbols
    - Both fields can be set on the repository or version levels. This allows using different preprocessor symbols for different pipelines, such as different preprocessor symbols for the Current pipeline and the Next-Major pipeline.
    - **Kepty_includedPreProcessorSymbols**
        - Add preprocessor symbols that should be used
    - **Kepty_preProcessorSymbolsVersion**
        - Add Azure DevOps variable name that specifies preprocessor symbols that should be used (see below the Azure DevOps Variables section)
- To be able to generate app files and dependencies
    - **Kepty_publishAppFileLocation**
        - Specifies the folder where generated app files should be stored
    - **Kepty_sourceAppAppJsonFileLocation**
        - Specifies subfolder in your project where the app file for your App is stored. This address is relative to the folder with CI/CD scripts.
    - **Kepty_sourceTestAppJsonFileLocation**
        - Specifies subfolder in your project where the app file for your Test app is stored. This address is relative to the folder with CI/CD scripts.

## Create a pipeline

- In Azure DevOps, go to *Pipelines*, select *New Pipelines*, *Azure Repos Git*, select your repository, *Existing Azure Pipelines YAML file*, select the YAML file you want to use for the pipeline (CI, Current, Next-Major or Next-Minor) and using the arrow next to *Run* choose *Save*.
- Create a variable group and set variables (see the *Azure DevOps Variables* section)

### Azure DevOps Variables

You can use Azure DevOps Variables to set up pipelines. The variables must be created within the **BuildVariables** Variable Group.

- To include preprocessor symbols
    - **Kepty_PreProcessorSymbolsCurrent**
    - **Kepty_PreProcessorSymbolsNextMajor**
        - You can use these variables to define preprocessor symbols that should be used in your pipelines. You can define multiple preprocessor symbols divided by a comma.
        - Example: 
            - **Kepty_PreProcessorSymbolsCurrent: CLEAN21,CLEAN22,CLEAN23**
            - **Kepty_PreProcessorSymbolsNextMajor: CLEAN22,CLEAN23,CLEAN24**
        - Which preprocessor symbol version should be used is defined in the settings.json file using the Kepty_preProcessorSymbolsVersion config.
        - Example:
            - **"Kepty_preProcessorSymbolsVersion": "Current"**
            - **"Kepty_preProcessorSymbolsVersion": "Next-Major"**
- To be able to run Next-Minor and Next-Major, you must provide Insider SAS Token.
    - **insiderSasToken**
        - This token can be obtained from your Partner Portal (from the contribution section, see my [post **How to install Business Central (developer) preview version**](https://kepty.cz/2021/06/18/how-to-install-business-central-developer-preview-version/))
        - To use this token, add {INSIDERSASTOKEN} placeholder to the artifact definition in your settings.json. See the template for the Next-Minor and Next-Major pipelines.
        - Example: **"artifact": "///{COUNTRY}/NextMajor/{INSIDERSASTOKEN}"**
- To use specific BC versions for your pipelines
    - **Kepty_artifactType**
        - Could be OnPrem or Sandbox
    - **Kepty_artifactVersion**
        - The version should be fully defined (for example, 21.0.46256.0)
        - For Kepty_artifactType = Sandbox, the version must exist as an artifact
        - For Kepty_artifactType = OnPrem, the pipeline will use only the first two digits from the version (for example, 21.0), and the latest published release for this version will be automatically used.
    - Using these tokens, you can specify the exact BC version that should be used for the pipeline.
    - To use this token, add {ARTIFACTTYPE} and {ARTIFACTVERSION} placeholders to the artifact definition in your settings.json.
    - Example: **"artifact": "/{ARTIFACTTYPE}/{ARTIFACTVERSION}/{COUNTRY}"**
- To sign generated app file with code signing certificate
    - **CodeSignCertPfxFile**
    - **CodeSignCertPfxPassword**

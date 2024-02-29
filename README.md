# Intune-Mobile-Number-to-AD

This script gets recently created users within 10 days from AD and checks Intune for their mobile device and updates AD Mobile Attribute. 

Script does the following:
- Gets Intune Mobile Number
- Formats the number
- Adds mobile number to mobile attribute
- If there is already a number, the process is skipped

  It is best practive to run this script 24 hours after the mobile devices has been assigned to the user. If the phone number is changed on the device, Intune can take up to 24 hours to reflect the new number.

  [!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/rcb0727)

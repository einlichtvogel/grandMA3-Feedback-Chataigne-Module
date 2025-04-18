var wingArray = [
  { start: 1, end: 15 }, //wing 1
  { start: 16, end: 30 }, //wing 2
  { start: 31, end: 45 }, //wing 3
  { start: 46, end: 60 }, //wing 4
  { start: 61, end: 75 }, //wing 5
  { start: 76, end: 90 }, //wing 6
];

function formatNumber(num) {
  if (num < 10) {
    return '0' + num;  // Führende Null hinzufügen, wenn die Zahl kleiner als 10 ist
  }
  return num;  // Andernfalls die Zahl als String zurückgeben
}

function getWingNumberFromButtonNumber(execNumber) {
  for (var i = 0; i < wingArray.length; i++) {
    if (execNumber >= formatNumber(wingArray[i].start) && execNumber <= formatNumber(wingArray[i].end)) {
      return i + 1; // Return the wing number (1-based index)
    }
  }

  return -1; // Return -1 if no valid wing number is found
}

function init() {
  script.log("Custom module init");

  for(a = 1; a <= 3; a++) {
    var param = local.values.addContainer(a === 1 ? "Color" : a === 2 ? "ColorString" : "Status");
    param.setCollapsed(false);

    var executors = param.addContainer("Executors");
    executors.setCollapsed(false);

    for (i = 1; i <= wingArray.length; i++) {
      var wing = executors.addContainer("Wing " + i);
      wing.setCollapsed(true);

      //Create containers for each row in the wing
      for (j = 1; j <= 4; j++) {
        var rowButtons = wing.addContainer("Row " + j + "00");
        rowButtons.setCollapsed(true);

        //Create buttons for each row
        for (f = wingArray[i - 1]["start"]; f <= wingArray[i - 1]["end"]; f++) {
          var buttonID = j + "" + formatNumber(f);
          var btn = rowButtons.addContainer("Button " + buttonID);
          btn.setCollapsed(true);

          if (a === 1) {
            // Color
            btn.addColorParameter("Color", "Color for button " + buttonID, 0x000000FF);
          }
          if (a === 2) {
            // Color String
            btn.addStringParameter("ColorString", "Color for button " + buttonID + "as string", "0;0;0;0");
          }
          if (a === 3) {
            // Status
            btn.addBoolParameter("Status", "Button " + buttonID + " on/off", false);
          }
        }
      }
    }

    var xkeys = executors.addContainer("xKeys");
    xkeys.setCollapsed(true);

    //Create containers for each row in the x-keys
    for (j = 1; j <= 2; j++) {
      var rowButtons = xkeys.addContainer("Row " + j + "00");
      rowButtons.setCollapsed(true);

      //Create buttons for each row
      for (f = 1; f <= 8; f++) {
        var buttonID = j + "9" + f;
        var btn = rowButtons.addContainer("Button " + buttonID);
        btn.setCollapsed(true);

        if (a === 1) {
          // Color
          btn.addColorParameter("Color", "Color for button " + buttonID, 0x000000FF);
        }
        if (a === 2) {
          // Color String
          btn.addStringParameter("ColorString", "Color for button " + buttonID + "as string", "0;0;0;0");
        }
        if (a === 3) {
          // Status
          btn.addBoolParameter("Status", "Button " + buttonID + " on/off", false);
        }
      }
    }
  }
}

function oscEvent(address, args) {
  script.log("OSC event received: " + address + ", args: " + args);

  // Check if the address starts with "/Exec"
  if (address.startsWith("/Exec")) {


    var execNumber = address.split("/")[1].split("c")[1];
    var rowNumber = execNumber.charAt(0);
    var buttonNumber = execNumber.charAt(1) + "" + execNumber.charAt(2);
    var type = address.split("/")[2];

    var btn, btnString;

    if(type === "Button"){
      if(parseInt(buttonNumber) >= 91 && (parseInt(buttonNumber) <= 98)) {
        // X-Keys
        btn = local.values["status"]["executors"]["xKeys"]["row" + rowNumber + "00"]["button" + execNumber];
      }else{
        btn = local.values["status"]["executors"]["wing" + getWingNumberFromButtonNumber(buttonNumber)]["row" + rowNumber + "00"]["button" + execNumber];
      }

      btn.status.set(args[0] === "On");
    }

    if(type === "Color") {
        // Set the color parameter of the button
        if(parseInt(buttonNumber) >= 91 && (parseInt(buttonNumber) <= 98)) {
            // X-Keys
            btn = local.values["color"]["executors"]["xKeys"]["row" + rowNumber + "00"]["button" + execNumber];
            btnString = local.values["colorString"]["executors"]["xKeys"]["row" + rowNumber + "00"]["button" + execNumber];
        }else{
            btn = local.values["color"]["executors"]["wing" + getWingNumberFromButtonNumber(buttonNumber)]["row" + rowNumber + "00"]["button" + execNumber];
            btnString = local.values["colorString"]["executors"]["wing" + getWingNumberFromButtonNumber(buttonNumber)]["row" + rowNumber + "00"]["button" + execNumber];
        }

        var spl = args[0].split(";");

        var newCol = [1,1,1,1];
        for(var i=0;i<spl.length-1;i++) newCol[i] = parseInt(spl[i])/255.0;

        btn.color.set(newCol);
        btnString.colorString.set(args[0]);
    }
  }

}
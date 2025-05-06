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
  script.log("--- grandMA3 Feedback OSC module init ---");

  local.parameters.addStringParameter("executorsToWatchAnyPage", "executorsToWatchAnyPage", "");
  local.parameters.addStringParameter("pages", "pages", "");
  local.parameters.addBoolParameter("loadAllExecutorsForPages", "loadAllExecutorsForPages", false);

  //init the static current page values
  var currentPage = local.values.addContainer("Current Page");

  //Create containers for each color and status
  for(a = 1; a <= 2; a++) {
    var param = currentPage.addContainer(a === 1 ? "Color" : "Status");
    param.setCollapsed(false);

    //go through all wings
    for (i = 1; i <= wingArray.length; i++) {
      var wing = param.addContainer("Wing " + i);
      wing.setCollapsed(true);

      //Create containers for each row in the wing (1-4)
      for (j = 1; j <= 4; j++) {
        var rowButtons = wing.addContainer("Row " + j + "00");
        rowButtons.setCollapsed(true);

        //Create buttons for each row (1-15)
        for (f = wingArray[i - 1]["start"]; f <= wingArray[i - 1]["end"]; f++) {
          var buttonID = j + "" + formatNumber(f);


          var btn;
          if (a === 1) {
            // Color
            btn = rowButtons.addColorParameter("Button " + buttonID, "Color for button " + buttonID, 0x000000FF);
          }
          if (a === 2) {
            // Status
            btn = rowButtons.addBoolParameter("Button " + buttonID, "Button " + buttonID + " on/off", false);
          }

          btn.setAttribute("saveValueOnly", false);
        }
      }
    }

    var xkeys = param.addContainer("xKeys");
    xkeys.setCollapsed(true);

    //go through each row in the x-keys (1-2)
    for (j = 1; j <= 2; j++) {
      var rowButtons = xkeys.addContainer("Row " + j + "00");
      rowButtons.setCollapsed(true);

      //Create buttons for each row (1-8)
      for (f = 1; f <= 8; f++) {
        var buttonID = j + "9" + f;

        var btn;
        if (a === 1) {
          // Color
          btn = rowButtons.addColorParameter("Button " + buttonID, "Color for button " + buttonID, 0x000000FF);
        }
        if (a === 2) {
          // Status
          btn =rowButtons.addBoolParameter("Button " + buttonID, "Button " + buttonID + " on/off", false);
        }

        btn.setAttribute("saveValueOnly", false);
      }
    }
  }
}

function oscEvent(address, args) {

  //Setup values
  if (address.startsWith("/Setup")){
    var todo = address.split("/")[2];

    //save the values from grandMA plugin to the local parameters
    if(todo === "executorsToWatchAnyPage") {
      local.parameters.executorsToWatchAnyPage.set(args[0] === "nil" ? "" : args[0]);
    }

    //save the values from grandMA plugin to the local parameters
    if(todo === "pages") {
      local.parameters.pages.set(args[0]);
    }

    //start setup called by grandMA plugin
    if(todo === "setupAllValues")
      var pages = local.parameters.pages.get().split(";");
      var execsAnyPage = local.parameters.executorsToWatchAnyPage.get().split(";");

      if(local.parameters.executorsToWatchAnyPage.get() === "nil" || local.parameters.executorsToWatchAnyPage.get() === "") {
        return;
      }

      //delete all pages to recreate them, if they already exist
      if(pages !== undefined){
        for (var h = 0; h < pages.length; h++) {
          var pageNumber = pages[h].split(" ")[1];

          if(local.values["page" + pageNumber] !== undefined) {
            local.values.removeContainer("page" + pageNumber);
          }
        }
      }

      //create all pages with new buttons
      for (var i = 0; i < pages.length; i++) {
        var name = pages[i]; // Page X

        var currentPage = local.values.addContainer(name);

        //Create containers for color and status
        for(a = 1; a <= 2; a++) {
          var param = currentPage.addContainer(a === 1 ? "Color" : "Status");
          param.setCollapsed(false);

          //Create containers for all execs when loadAllExecutorsForPages is true
          if(local.parameters.loadAllExecutorsForPages.get()) {
            //Create containers for each wing
            for (wi = 1; wi <= wingArray.length; wi++) {
              var wing = param.addContainer("Wing " + wi);
              wing.setCollapsed(true);

              //Create containers for each row in the wing
              for (j = 1; j <= 4; j++) {
                var rowButtons = wing.addContainer("Row " + j + "00");
                rowButtons.setCollapsed(true);

                //Create buttons for each row
                for (f = wingArray[wi - 1]["start"]; f <= wingArray[wi - 1]["end"]; f++) {
                  var buttonID = j + "" + formatNumber(f);

                  var btn;

                  if (a === 1) {
                    // Color
                    btn = rowButtons.addColorParameter("Button " + buttonID, "Color for button " + buttonID, 0x000000FF);
                  }
                  if (a === 2) {
                    // Status
                    btn = rowButtons.addBoolParameter("Button " + buttonID, "Button " + buttonID + " on/off", false);
                  }

                  btn.setAttribute("saveValueOnly", false);
                }
              }
            }

            var xkeys = param.addContainer("xKeys");
            xkeys.setCollapsed(true);

            //Create containers for each row in the x-keys
            for (j = 1; j <= 2; j++) {
              var rowButtons = xkeys.addContainer("Row " + j + "00");
              rowButtons.setCollapsed(true);

              //Create buttons for each row
              for (f = 1; f <= 8; f++) {
                var buttonID = j + "9" + f;

                var btn;

                if (a === 1) {
                  // Color
                  btn = rowButtons.addColorParameter("Button " + buttonID, "Color for button " + buttonID, 0x000000FF);
                }
                if (a === 2) {
                  // Status
                  btn = rowButtons.addBoolParameter("Button " + buttonID, "Button " + buttonID + " on/off", false);
                }

                btn.setAttribute("saveValueOnly", false);
              }
            }
          }else{
            //Create containers only for those execs who got sent from grandMA
            //101-103;102-104
            for (var j = 0; j < execsAnyPage.length; j++) {
              var execNumberFrom = parseInt(execsAnyPage[j].split("-")[0]);
              var execNumberTo = parseInt(execsAnyPage[j].split("-")[1]);

              //go through each exec range
              //101 - 103
              for (var f = execNumberFrom; f <= execNumberTo; f++) {
                var buttonID = f + ""; // 101
                var rowNumber = buttonID.charAt(0); // 1
                var buttonNumber = buttonID.charAt(1) + "" + buttonID.charAt(2); // 01

                var wingNumber = getWingNumberFromButtonNumber(buttonNumber);

                var wing;

                if (parseInt(buttonNumber) >= 91 && (parseInt(buttonNumber) <= 98)) {
                  // X-Keys
                  if (param["xKeys"] === undefined) {
                    wing = param.addContainer("xKeys");
                  }else{
                    wing = param["xKeys"];
                  }
                }else{
                  if(param["Wing " + wingNumber] === undefined) {
                    wing = param.addContainer("Wing " + wingNumber);
                  }else{
                    wing = param["Wing " + wingNumber];
                  }
                }

                var row;

                if(wing["Row " + rowNumber + "00"] === undefined) {
                  row = wing.addContainer("Row " + rowNumber + "00");
                }else{
                  row = wing["Row " + rowNumber + "00"];
                }

                if(row["Button " + buttonID] === undefined) {
                  var btn;

                  if (a === 1) {
                    // Color
                    btn = row.addColorParameter("Button " + buttonID, "Color for button " + buttonID, 0x000000FF);
                  }
                  if (a === 2) {
                    // Status
                    btn = row.addBoolParameter("Button " + buttonID, "Button " + buttonID + " on/off", false);
                  }

                  btn.setAttribute("saveValueOnly", false);
                }
              }
            }
          }
        }
      }
  }

  //Page Specific Executors (executorsToWatchAnyPage)
  if (address.startsWith("/Page")){
    var pageNumber = address.split("/")[1].split("e")[1];

    var execNumber = address.split("/")[2].split("c")[1];
    var rowNumber = execNumber.charAt(0);
    var buttonNumber = execNumber.charAt(1) + "" + execNumber.charAt(2);
    var type = address.split("/")[3];

    var btn;

    if (parseInt(buttonNumber) >= 91 && (parseInt(buttonNumber) <= 98)) {
      // X-Keys
      btn = local.values["page" + pageNumber][type === "Color" ? "color" : "status"]["xKeys"]["row" + rowNumber + "00"]["button" + execNumber];
    } else {
      btn = local.values["page" + pageNumber][type === "Color" ? "color" : "status"]["wing" + getWingNumberFromButtonNumber(buttonNumber)]["row" + rowNumber + "00"]["button" + execNumber];
    }

    if (type === "Button") {
      btn.set(args[0] === "On");
    }

    if (type === "Color") {
      var spl = args[0].split(";");

      var newCol = [1, 1, 1, 1];
      for (var i = 0; i < spl.length - 1; i++) newCol[i] = parseInt(spl[i]) / 255.0;

      btn.set(newCol);
    }
  }

  //Page Non-Specific Executors (executorsToWatchCurrentPage - selected page in MA)
  if (address.startsWith("/Exec")) {

    var execNumber = address.split("/")[1].split("c")[1];
    var rowNumber = execNumber.charAt(0);
    var buttonNumber = execNumber.charAt(1) + "" + execNumber.charAt(2);
    var type = address.split("/")[2];

    var btn;

    if (parseInt(buttonNumber) >= 91 && (parseInt(buttonNumber) <= 98)) {
      // X-Keys
      btn = local.values["currentPage"][type === "Color" ? "color" : "status"]["xKeys"]["row" + rowNumber + "00"]["button" + execNumber];
    } else {
      btn = local.values["currentPage"][type === "Color" ? "color" : "status"]["wing" + getWingNumberFromButtonNumber(buttonNumber)]["row" + rowNumber + "00"]["button" + execNumber];
    }

    if (type === "Button") {
      btn.set(args[0] === "On");
    }

    if (type === "Color") {
      var spl = args[0].split(";");

      var newCol = [1, 1, 1, 1];
      for (var i = 0; i < spl.length - 1; i++) newCol[i] = parseInt(spl[i]) / 255.0;

      btn.set(newCol);
    }
  }

}

function resetAllValues() {
  var pages = local.parameters.pages.get().split(";");
  var execsAnyPage = local.parameters.executorsToWatchAnyPage.get().split(";");

  //run mode color and status through
  for (a = 1; a <= 2; a++) {

    //go to all execs available in ma
    if(local.parameters.loadAllExecutorsForPages.get()) {

      //go through all pages
      for (h = 0; h < pages.length; h++) {
        var pageNumber = pages[h].split(" ")[1];

        //go through each wing
        for (i = 1; i <= wingArray.length; i++) {

          //go through each row (1-4)
          for (j = 1; j <= 4; j++) {

            //go through each exec in the wing
            for (f = wingArray[i - 1]["start"]; f <= wingArray[i - 1]["end"]; f++) {
              var buttonID = j + "" + formatNumber(f);
              local.values["page" + pageNumber][a === 1 ? "color" : "status"]["wing" + i]["row" + j + "00"]["button" + buttonID].set(a === 1 ? 0xFF000000 : false);
            }
          }
        }

        //go through each row in the x-keys (1-2)
        for (j = 1; j <= 2; j++) {

            //go through each exec in the x-keys (1-8)
          for (f = 1; f <= 8; f++) {
            var buttonID = j + "9" + f;
            local.values["page" + pageNumber][a === 1 ? "color" : "status"]["xKeys"]["row" + j + "00"]["button" + buttonID].set(a === 1 ? 0xFF000000 : false);
          }
        }
      }


    //go through all executors on the current page
    }else{
        //go through all pages
      for (h = 0; h < pages.length; h++) {
        var pageNumber = pages[h].split(" ")[1];

        //go through each exec range that should be watched, where the page is the current selected in ma
        for (j = 0; j < execsAnyPage.length; j++) {
          var execNumberFrom = parseInt(execsAnyPage[j].split("-")[0]);
          var execNumberTo = parseInt(execsAnyPage[j].split("-")[1]);

          //go through each exec range
          for (var f = execNumberFrom; f <= execNumberTo; f++) {
            var buttonID = f + ""; // 101
            var rowNumber = buttonID.charAt(0); // 1
            var buttonNumber = buttonID.charAt(1) + "" + buttonID.charAt(2); // 01

            var wingNumber = getWingNumberFromButtonNumber(buttonNumber);

            if (parseInt(buttonNumber) >= 91 && (parseInt(buttonNumber) <= 98)) {
              // X-Keys
              local.values["page" + pageNumber][a === 1 ? "color" : "status"]["xKeys"]["row" + rowNumber + "00"]["button" + buttonID].set(a === 1 ? 0xFF000000 : false);
            } else {
              // Normals
              local.values["page" + pageNumber][a === 1 ? "color" : "status"]["wing" + wingNumber]["row" + rowNumber + "00"]["button" + buttonID].set(a === 1 ? 0xFF000000 : false);
            }
          }
        }
      }
    }

    //go through each wing in "Current Page"
    for (i = 1; i <= wingArray.length; i++) {
        //go through each row (1-4)
      for (j = 1; j <= 4; j++) {
        //go through each exec in the wing
        for (f = wingArray[i - 1]["start"]; f <= wingArray[i - 1]["end"]; f++) {
          var buttonID = j + "" + formatNumber(f);
          local.values["currentPage"][a === 1 ? "color" : "status"]["wing" + i]["row" + j + "00"]["button" + buttonID].set(a === 1 ? 0xFF000000 : false);
        }
      }
    }

    //go through each row in the x-keys (1-2)
    for (j = 1; j <= 2; j++) {
        //go through each exec in the x-keys (1-8)
      for (f = 1; f <= 8; f++) {
        var buttonID = j + "9" + f;
        local.values["currentPage"][a === 1 ? "color" : "status"]["xKeys"]["row" + j + "00"]["button" + buttonID].set(a === 1 ? 0xFF000000 : false);
      }
    }
  }
}
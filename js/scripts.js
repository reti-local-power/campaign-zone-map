var coll = document.getElementsByClassName("collapsible");
var i;

for (i = 0; i < coll.length; i++) {
  coll[i].addEventListener("click", function () {
    this.classList.toggle("active");
    var content = this.nextElementSibling;
    if (content.style.display === "block") {
      content.style.display = "none";
    } else {
      content.style.display = "block";
    }
  });
}

// Script to collapse/open the side panel
/* Set the width of the sidebar to 30% (show it) */
function openNav() {
  document.getElementById("my-sidepanel").style.width = "30%";
  document.getElementbyId("my-map-container").style.width = "68%"; // Return to original width
}

/* Set the width of the sidebar to 0 (hide it) */
function closeNav() {
  document.getElementById("my-sidepanel").style.width = "0";
  document.getElementbyId("my-map-container").style.width = "100%"; // Expand to full page
} 


// $(".collapsible").click(function () {
//   $(".collapsible").css('background', '#679a67');
// });

// function expandContract() {
//   const el = document.getElementById("expand-contract")
//   el.classList.toggle('expanded')
//   el.classList.toggle('collapsed')
// }

// Add active class (highlight button) to the button that is currently clicked
// var header = document.getElementById("column-left");
// var btns = header.getElementsByClassName("collapsible");
// for (var i = 0; i < btns.length; i++) {
//   btns[i].addEventListener("click", function () {
//     var current = document.getElementsByClassName("active");
//     if (current.length > 0) {
//       current[0].className = current[0].className.replace(" active", "");
//     }
//     this.className += " active";
//   });
// }
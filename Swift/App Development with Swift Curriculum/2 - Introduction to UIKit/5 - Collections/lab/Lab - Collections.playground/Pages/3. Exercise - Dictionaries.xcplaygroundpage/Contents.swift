/*:
 ## Exercise - Dictionaries
 
 Create a variable `[String: Int]` dictionary that can be used to look up the number of days in a particular month. Use a dictionary literal to initialize it with January, February, and March. January contains 31 days, February has 28, and March has 31. Print the dictionary.
 */
var daysPerMonth: [String: Int] = ["January": 31, "February": 28, "March": 31]
print("Days in the first three months: \(daysPerMonth)")


/*:
 Using subscripting syntax to add April to the collection with a value of 30. Print the dictionary.
 */
daysPerMonth["April"] = 30
print("Days in the first four months: \(daysPerMonth)")

/*:
 It's a leap year! Update the number of days in February to 29 using the `updateValue(_:, forKey:)` method. Print the dictionary.
 */
daysPerMonth.updateValue(29, forKey: "February")
print("Days in the first four months (on a leap year): \(daysPerMonth)")

/*:
 Use if-let syntax to retrieve the number of days under "January". If the value is there, print "January has 31 days", where 31 is the value retrieved from the dictionary.
 */
if let daysInJanuary = daysPerMonth["Octember"] {
    print("January has \(daysInJanuary) days")
} else {
    print("That doesn't exist.")
}

/*:
 Given the following arrays, create a new [String : [String]] dictionary. `shapesArray` should use the key "Shapes" and `colorsArray` should use the key "Colors". Print the resulting dictionary.
 */
let shapesArray = ["Circle", "Square", "Triangle"]
let colorsArray = ["Red", "Green", "Blue"]

var characteristicDictionary = ["Shapes": shapesArray, "Colors": colorsArray]
print(characteristicDictionary)


/*:
 Print the last element of `colorsArray`, accessing it through the dictionary you've created. You'll have to use if-let syntax or the bang operator to unwrap what is returned from the dictionary before you can access element of the array.
 */
if let lastElementOfColorsArray = characteristicDictionary["Colors"]?.last {
    print("The last element of colorsArray: \(lastElementOfColorsArray)")
}

//: [Previous](@previous)  |  page 3 of 4  |  [Next: App Exercise - Pacing](@next)

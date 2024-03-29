/*:
 ## Putting It All Together
 - callout(Exercise): In this final exercise you’ll combine the things you’ve learned over the last few pages. Update this `responseToQuestion` function so that it gives the answers specified below. It’s OK to go back and look and code from earlier pages.
*/
func responseTo(question: String) -> String {
    let lowerQuestion = question.lowercased()
    if lowerQuestion == "where are the cookies?" {
        return "In the cookie jar!"
    } else if lowerQuestion.hasPrefix("hello") {
        return "Why, hello there!"
    } else if lowerQuestion.hasPrefix("where") {
        return "To the North!"
    } else {
        // number choosing generic response based on character count
        let number = lowerQuestion.count % 4
        
        if number == 0 {
            return "I'm not quite sure I understand the question."
        } else if number == 1 {
            return "idk what u askd man but just dab on them h8rs"
        } else if number == 2 {
            return "Ask me l8r"
        } else {
            return "What do YOU think?"
        }
    }
}
//: 👇These answers should be “Why, hello there!”
responseTo(question: "Hello there")
responseTo(question: "hello there")
//: 👇These answers should be “To the North!”
responseTo(question: "Where should I go on holiday?")
responseTo(question: "where can I find the North Pole?")
//: 👇This answer should be “In the cookie jar!”
responseTo(question: "Where are the cookies?")
/*: 
 Any other question can have any answer you'd like. You can also make new rules or conditions so different questions have different answers!
 
 👇 Below are some example questions for you to test the final part. You can add or change the test questions if you like.
*/
responseTo(question: "Can I have a cookie?")
responseTo(question: "CAN I HAVE A COOKIE?!?")
responseTo(question: "Should I go?")

/*:
 - note:
 You'll be cutting and pasting the body of the `responseToQuestion` function above. When you highlight it to copy over, your function body will be different, but it'll look something like this:\
 ![](copy-paste-example.png)
 */

//:[Previous](@previous)  |  page 6 of 7  |  [Next: Wrapup](@next)


Scanner scan = new Scanner(System.in);
Random random = new Random();
long from = 1;
long to = 100;
int randomNumber = random.nextInt(to - from + 1) + from;
int guessedNumber = 0;
int guesses = 0;

do {
  System.out.print("Guess the number: ");
  guesses++;
  guessedNumber = scan.nextInt();
  if (guessedNumber > randomNumber) {
    System.out.println("Too high!");
  } else if (guessedNumber < randomNumber) {
    System.out.println("Too low!");
  } else {
    System.out.println("You got it!");
    System.out.println("It took you " + guesses + " guesses.");
  }
} while (guessedNumber != randomNumber);
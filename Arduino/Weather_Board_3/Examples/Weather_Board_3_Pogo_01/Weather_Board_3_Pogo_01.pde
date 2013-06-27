// digital I/O pins
const int RAIN3 = 4;
const int RAIN4 = 5;
const int WIND3 = 6;
const int WIND4 = 7;
const int STATUS = A1;

void setup() 
{
  // make pins inputs first
  pinMode(RAIN3,INPUT);
  digitalWrite(RAIN3,LOW); // turn off pullup
  pinMode(RAIN4,INPUT);
  digitalWrite(RAIN4,LOW); // turn off pullup
  pinMode(WIND3,INPUT);
  digitalWrite(WIND3,LOW); // turn off pullup
  pinMode(WIND4,INPUT);
  digitalWrite(WIND4,LOW); // turn off pullup

  pinMode(STATUS,OUTPUT);
}

void loop()
{
  // make pins outputs / low
  pinMode(RAIN3,OUTPUT);
  digitalWrite(RAIN3,LOW);
  pinMode(RAIN4,OUTPUT);
  digitalWrite(RAIN4,LOW);
  pinMode(WIND3,OUTPUT);
  digitalWrite(WIND3,LOW);
  pinMode(WIND4,OUTPUT);
  digitalWrite(WIND4,LOW);

  digitalWrite(STATUS,HIGH);

  delay(10);

  // make pins high-Z (disconnected)
  pinMode(RAIN3,INPUT);
  pinMode(RAIN4,INPUT);
  pinMode(WIND3,INPUT);
  pinMode(WIND4,INPUT);

  digitalWrite(STATUS,LOW);

  delay(90);
}

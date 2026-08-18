package main

import (
	"fmt"
	"os"

	"github.com/resend/resend-go/v2"
)

func main() {
	apiKey := "re_62xJif9f_GLQRcWTHgpzop6bU7UWexZnv"
	client := resend.NewClient(apiKey)

	params := &resend.SendEmailRequest{
		From:    "no-reply@khair.it.com",
		To:      []string{"hassanalwaqedi3@gmail.com"},
		Subject: "Test Email from Khair",
		Html:    "<p>This is a test email to check if Resend is working.</p>",
	}

	sent, err := client.Emails.Send(params)
	if err != nil {
		fmt.Printf("Error sending email: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Email sent successfully! ID: %s\n", sent.Id)
}

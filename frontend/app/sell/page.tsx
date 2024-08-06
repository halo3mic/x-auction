"use client";

import { BookLock, Lock } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";

export default function Page() {
  const [secret, setSecret] = useState("");
  const [description, setDescription] = useState("");

  const inputFields = [
    {
      label: "Secret Description",
      icon: BookLock,
      placeholder:
        "Provide a brief description of your secret to attract potential bidders.",
      value: description,
      setValue: setDescription,
    },
    {
      label: "Your Secret",
      icon: Lock,
      placeholder: "Paste your secret here",
      value: secret,
      setValue: setSecret,
    },
  ];
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    // TODO: Implement transaction signing and auction offering logic
    console.log("Secret submitted:", secret);
    console.log("Description submitted:", description);
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-background">
      <Card className="w-[420px] shadow-lg relative">
        <div className="absolute -top-6 p-3 left-1/2 -translate-x-1/2 border bg-background rounded-full shadow-sm">
          <Lock className="text-primary" size={24} />
        </div>

        <CardHeader className="pt-10 text-center">
          <CardTitle className="text-2xl font-bold">
            Offer Secret for Auction
          </CardTitle>
          <CardDescription>
            Sign and offer your secret for auction
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-6">
          {inputFields.map(
            ({ label, icon: Icon, placeholder, value, setValue }) => (
              <div key={label} className="space-y-2">
                <label className="flex items-center text-sm font-medium">
                  <Icon className="text-primary mr-2" size={18} />
                  {label}
                </label>
                <Textarea
                  placeholder={placeholder}
                  value={value}
                  onChange={(e) => setValue(e.target.value)}
                  className="min-h-[80px] bg-muted"
                />
              </div>
            ),
          )}
        </CardContent>

        <CardFooter className="pt-2">
          <Button
            type="submit"
            className="w-full font-semibold"
            size="lg"
            onClick={handleSubmit}
          >
            Sign & Offer for Auction
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
}

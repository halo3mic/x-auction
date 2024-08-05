"use client";

import { ArrowRight, BookLock, Clock, Lock } from "lucide-react";
import { useState } from "react";
import Countdown from "react-countdown";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function Page() {
  const [bidAmount, setBidAmount] = useState(1.51);
  const endTime = Date.now() + 2 * 24 * 60 * 60 * 1000 + 12 * 60 * 60 * 1000; // 2 days and 12 hours from now

  return (
    <div className="flex items-center justify-center min-h-screen bg-background">
      <Card className="w-[420px] shadow-lg relative bg-background border border-border">
        <div className="absolute -top-6 left-1/2 transform -translate-x-1/2 border border-border bg-background rounded-full p-3 shadow">
          <Lock className="text-primary" size={24} />
        </div>

        <CardHeader className="pt-10">
          <CardTitle className="text-2xl font-bold text-center">
            Bid on the Secret
          </CardTitle>
          <CardDescription className="text-center">
            Place your bid to reveal the secret
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-4">
          <Card className="border border-border p-4">
            <div className="flex items-center mb-2">
              <BookLock className="text-primary" size={24} />
              <Label className="text-sm font-medium text-muted-foreground ml-2">
                Secret Description
              </Label>
            </div>
            <p className="text-sm text-foreground">
              This secret contains valuable information that could change your
              perspective on the current market trends. Don&apos;t miss out on
              this opportunity!
            </p>
          </Card>

          <div className="grid grid-cols-2 gap-4">
            <Card className="bg-secondary shadow-sm">
              <CardHeader className="p-4 text-center">
                <CardTitle className="text-lg font-semibold text-muted-foreground">
                  Current Bid
                </CardTitle>
                <CardDescription className="text-3xl font-bold text-foreground">
                  1.5 ETH
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="bg-secondary shadow-sm">
              <CardHeader className="p-4 text-center">
                <CardTitle className="text-lg font-semibold text-muted-foreground">
                  Time Remaining
                </CardTitle>
                <CardDescription className="text-base font-semibold flex items-center text-foreground">
                  <Clock className="mr-1" size={16} />
                  <Countdown
                    date={endTime}
                    renderer={({ days, hours, minutes, seconds }) => (
                      <span>
                        {days}d {hours}h {minutes}m {seconds}s
                      </span>
                    )}
                  />
                </CardDescription>
              </CardHeader>
            </Card>
          </div>

          <Card className="border border-border p-4">
            <div className="flex justify-between items-center mb-2">
              <Label
                htmlFor="bid"
                className="text-sm font-medium text-muted-foreground"
              >
                Your Bid (ETH)
              </Label>
              <span className="text-sm text-muted-foreground">
                Balance: 10 ETH
              </span>
            </div>
            <div className="relative">
              <Input
                id="bid"
                type="number"
                value={bidAmount}
                onChange={(e) =>
                  setBidAmount(Number.parseFloat(e.target.value))
                }
                className="text-3xl font-bold p-6 pr-16"
                step="0.01"
                min="1.51"
              />
              <Button
                variant="ghost"
                className="absolute right-1 top-1/2 transform -translate-y-1/2 text-primary font-semibold"
                onClick={() => setBidAmount(10)} // Assuming max balance is 10 ETH
              >
                MAX
              </Button>
            </div>
            <p className="text-sm text-muted-foreground mt-2">
              Minimum increment: 0.01 ETH
            </p>
          </Card>
        </CardContent>

        <CardFooter>
          <Button className="w-full" size="lg" variant="default">
            <span>Place Bid</span>
            <ArrowRight className="ml-2" size={18} />
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
}

"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import {
	Card,
	CardContent,
	CardHeader,
	CardTitle,
	CardFooter,
	CardDescription,
} from "@/components/ui/card";
import { Lock, BookLock } from "lucide-react";

export default function Page() {
	const [secret, setSecret] = useState("");
	const [description, setDescription] = useState("");

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		// TODO: Implement transaction signing and auction offering logic
		console.log("Secret submitted:", secret);
		console.log("Description submitted:", description);
	};

	return (
		<div className="flex items-center justify-center min-h-screen bg-background">
			<Card className="w-[420px] shadow-lg relative">
				<div className="absolute -top-6 left-1/2 transform -translate-x-1/2 border border-border bg-background rounded-full p-3 shadow-sm">
					<Lock className="text-primary" size={24} />
				</div>

				<CardHeader className="pt-10 pb-6">
					<CardTitle className="text-2xl font-bold text-center">
						Offer Secret for Auction
					</CardTitle>
					<CardDescription className="text-center text-muted-foreground mt-1.5">
						Sign and offer your secret for auction
					</CardDescription>
				</CardHeader>

				<CardContent className="space-y-6">
					<div className="space-y-2">
						<label className="flex items-center text-sm font-medium text-foreground">
							<BookLock className="text-primary mr-2" size={18} />
							Secret Description
						</label>
						<Textarea
							placeholder="Provide a brief description of your secret to attract potential bidders."
							value={description}
							onChange={(e) => setDescription(e.target.value)}
							className="min-h-[80px] bg-muted border border-input focus:border-ring focus:ring-1 focus:ring-ring"
						/>
					</div>

					<div className="space-y-2">
						<label className="flex items-center text-sm font-medium text-foreground">
							<Lock className="text-primary mr-2" size={18} />
							Your Secret
						</label>
						<Textarea
							placeholder="Paste your secret here"
							value={secret}
							onChange={(e) => setSecret(e.target.value)}
							className="min-h-[80px] bg-muted border border-input focus:border-ring focus:ring-1 focus:ring-ring"
						/>
					</div>
				</CardContent>

				<CardFooter className="pt-2">
					<Button
						type="submit"
						className="w-full font-semibold transition-colors"
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

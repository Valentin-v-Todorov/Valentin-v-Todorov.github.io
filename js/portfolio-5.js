// 🚀 ENHANCED COMING SOON ANIMATION SYSTEM 🚀

// Particle system for background
function initParticleSystem() {
	const particlesContainer = document.querySelector('.particles');
	const particleCount = 20;

	for (let i = 0; i < particleCount; i++) {
		const particle = document.createElement('div');
		particle.className = 'particle';
		particle.style.left = Math.random() * 100 + '%';
		particle.style.animationDelay = Math.random() * 15 + 's';
		particle.style.animationDuration = (Math.random() * 10 + 10) + 's';
		particlesContainer.appendChild(particle);
	}
}

// Main scroll-triggered animations
function initScrollAnimations() {
	const observerOptions = {
		threshold: 0.1,
		rootMargin: '0px 0px -50px 0px'
	};

	const observer = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.classList.add('revealed');
			}
		});
	}, observerOptions);

	document.querySelectorAll('.scroll-reveal, .scroll-reveal-left, .scroll-reveal-right').forEach(el => {
		observer.observe(el);
	});
}

// Coming soon icon animation
function initComingSoonIcon() {
	const icon = document.querySelector('.coming-soon-icon');

	const iconObserver = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, 200);
			}
		});
	}, { threshold: 0.5 });

	if (icon) {
		iconObserver.observe(icon);
	}
}

// Main headers animation
function initMainHeaders() {
	const headers = document.querySelectorAll('.main-header');

	const headerObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 200);
			}
		});
	}, { threshold: 0.3 });

	headers.forEach(header => {
		headerObserver.observe(header);
	});
}

// Feature preview cards staggered animation
function initFeatureAnimations() {
	const featurePreviews = document.querySelectorAll('.feature-preview');

	const featureObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 200);
			}
		});
	}, { threshold: 0.2 });

	featurePreviews.forEach(preview => {
		featureObserver.observe(preview);
	});
}

// Timeline progressive reveal
function initTimelineAnimations() {
	const timelineItems = document.querySelectorAll('.timeline');

	const timelineObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 300);
			}
		});
	}, { threshold: 0.3 });

	timelineItems.forEach(item => {
		timelineObserver.observe(item);
	});
}

// Contact CTA animation
function initContactCTA() {
	const cta = document.querySelector('.contact-cta');

	const ctaObserver = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.classList.add('animate');

				// Animate CTA buttons
				const ctaButtons = entry.target.querySelectorAll('.cta-btn');
				ctaButtons.forEach((btn, index) => {
					setTimeout(() => {
						btn.classList.add('animate');
					}, 500 + (index * 150));
				});
			}
		});
	}, { threshold: 0.3 });

	if (cta) {
		ctaObserver.observe(cta);
	}
}

// Content stagger animation system
function initContentStagger() {
	const contentElements = document.querySelectorAll('.content-stagger');

	const contentObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 150);
			}
		});
	}, { threshold: 0.1 });

	contentElements.forEach(element => {
		contentObserver.observe(element);
	});
}

// Thank you section animation
function initThankYouAnimation() {
	const thankYou = document.querySelector('.thank-you-section');

	const thankYouObserver = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.classList.add('animate');
			}
		});
	}, { threshold: 0.5 });

	if (thankYou) {
		thankYouObserver.observe(thankYou);
	}
}

// Enhanced 3D hover effects for feature previews
function initFeature3DEffects() {
	document.querySelectorAll('.feature-preview').forEach(preview => {
		preview.addEventListener('mousemove', (e) => {
			const rect = preview.getBoundingClientRect();
			const x = e.clientX - rect.left;
			const y = e.clientY - rect.top;
			const centerX = rect.width / 2;
			const centerY = rect.height / 2;
			const deltaX = (x - centerX) / 10;
			const deltaY = (y - centerY) / 10;

			preview.style.transform = `
				perspective(1000px)
				rotateX(${deltaY}deg)
				rotateY(${deltaX}deg)
				translateY(-15px)
				scale(1.03)
			`;
		});

		preview.addEventListener('mouseleave', () => {
			preview.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) translateY(0) scale(1)';
		});
	});
}

// CTA button ripple effects
function initCTAButtonEffects() {
	document.querySelectorAll('.cta-btn').forEach(btn => {
		btn.addEventListener('click', function(e) {
			// Create ripple effect
			const ripple = document.createElement('span');
			const rect = this.getBoundingClientRect();
			const size = Math.max(rect.width, rect.height);
			const x = e.clientX - rect.left - size / 2;
			const y = e.clientY - rect.top - size / 2;

			ripple.style.cssText = `
				position: absolute;
				border-radius: 50%;
				background: rgba(102, 126, 234, 0.6);
				transform: scale(0);
				animation: ripple 0.6s linear;
				width: ${size}px;
				height: ${size}px;
				left: ${x}px;
				top: ${y}px;
				pointer-events: none;
			`;

			this.appendChild(ripple);

			setTimeout(() => {
				ripple.remove();
			}, 600);
		});
	});

	// Add ripple animation CSS
	if (!document.querySelector('#ripple-styles')) {
		const style = document.createElement('style');
		style.id = 'ripple-styles';
		style.textContent = `
			@keyframes ripple {
				to {
					transform: scale(4);
					opacity: 0;
				}
			}
		`;
		document.head.appendChild(style);
	}
}

// Parallax scrolling effect for header
function initParallaxEffect() {
	window.addEventListener('scroll', () => {
		const scrolled = window.pageYOffset;
		const header = document.querySelector('.project-header');
		if (header) {
			header.style.transform = `translateY(${scrolled * 0.3}px)`;
		}

		// Parallax for particles
		const particles = document.querySelectorAll('.particle');
		particles.forEach((particle, index) => {
			const speed = 0.5 + (index % 3) * 0.2;
			particle.style.transform += ` translateY(${scrolled * speed}px)`;
		});
	});
}

// Enhanced navigation effects
function initNavigationEffects() {
	const navLinks = document.querySelectorAll('.nav-links a');
	navLinks.forEach(link => {
		link.addEventListener('mouseenter', function() {
			this.style.transform = 'translateY(-2px) scale(1.05)';
			this.style.boxShadow = '0 5px 15px rgba(255, 107, 107, 0.4)';
		});
		link.addEventListener('mouseleave', function() {
			if (!this.classList.contains('active')) {
				this.style.transform = 'translateY(0) scale(1)';
				this.style.boxShadow = '';
			}
		});
	});
}

// Feature icon magnetic effect
function initFeatureIconEffects() {
	document.querySelectorAll('.feature-preview').forEach(preview => {
		const icon = preview.querySelector('.feature-icon');

		preview.addEventListener('mousemove', (e) => {
			const rect = preview.getBoundingClientRect();
			const x = e.clientX - rect.left;
			const y = e.clientY - rect.top;
			const centerX = rect.width / 2;
			const centerY = rect.height / 2;
			const deltaX = (x - centerX) / 20;
			const deltaY = (y - centerY) / 20;

			if (icon) {
				icon.style.transform = `translate(${deltaX}px, ${deltaY}px) scale(1.3) rotate(15deg)`;
			}
		});

		preview.addEventListener('mouseleave', () => {
			if (icon) {
				icon.style.transform = 'translate(0, 0) scale(1) rotate(0deg)';
			}
		});
	});
}

// Timeline hover enhancements
function initTimelineHoverEffects() {
	document.querySelectorAll('.timeline').forEach(timeline => {
		timeline.addEventListener('mouseenter', function() {
			this.style.transform = 'translateX(15px)';
			this.style.boxShadow = '0 15px 30px rgba(255, 107, 107, 0.2)';
			this.style.background = '#383838';
		});

		timeline.addEventListener('mouseleave', function() {
			this.style.transform = 'translateX(0)';
			this.style.boxShadow = '';
			this.style.background = '#333';
		});
	});
}

// Dynamic loading shimmer effect
function initShimmerEffect() {
	setTimeout(() => {
		document.querySelectorAll('.feature-preview').forEach((preview, index) => {
			preview.classList.add('shimmer');

			setTimeout(() => {
				preview.classList.remove('shimmer');
			}, 1000 + (index * 200));
		});
	}, 2000);
}

// Initialize all animations when page loads
document.addEventListener('DOMContentLoaded', function() {
	initParticleSystem();

	// Delay animation initialization for smooth loading
	setTimeout(() => {
		initScrollAnimations();
		initComingSoonIcon();
		initMainHeaders();
		initFeatureAnimations();
		initTimelineAnimations();
		initContactCTA();
		initContentStagger();
		initThankYouAnimation();
		initFeature3DEffects();
		initCTAButtonEffects();
		initParallaxEffect();
		initNavigationEffects();
		initFeatureIconEffects();
		initTimelineHoverEffects();
		// initShimmerEffect(); // Uncomment for loading shimmer

		// Add loaded class for final touches
		document.body.classList.add('animations-loaded');
	}, 200);
});

// Add smooth scrolling for anchor links
document.addEventListener('DOMContentLoaded', function() {
	document.querySelectorAll('a[href^="#"]').forEach(anchor => {
		anchor.addEventListener('click', function (e) {
			e.preventDefault();
			const target = document.querySelector(this.getAttribute('href'));
			if (target) {
				target.scrollIntoView({
					behavior: 'smooth',
					block: 'start'
				});
			}
		});
	});
});

// Special effects for development timeline
function addTimelineSpecialEffects() {
	document.querySelectorAll('.timeline').forEach((timeline, index) => {
		timeline.addEventListener('click', function() {
			// Add special click effect
			this.style.animation = 'none';
			setTimeout(() => {
				this.style.animation = 'timelinePulse 1s ease-in-out';
			}, 10);
		});
	});
}

// Initialize special effects after main animations
setTimeout(() => {
	addTimelineSpecialEffects();
}, 3000);
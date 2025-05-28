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

// Experience sections staggered animation
function initExperienceAnimations() {
	const experienceSections = document.querySelectorAll('.experience-section');

	const experienceObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');

					// Animate achievement list items
					const achievementItems = entry.target.querySelectorAll('.achievement-list li');
					achievementItems.forEach((item, i) => {
						setTimeout(() => {
							item.classList.add('animate');
						}, i * 100);
					});

					// Animate tech tags
					const techTags = entry.target.querySelectorAll('.tech-tag');
					techTags.forEach((tag, i) => {
						setTimeout(() => {
							tag.classList.add('animate');
						}, i * 50 + 300);
					});

					// Animate blog dates
					const blogDate = entry.target.querySelector('.blog-date');
					if (blogDate) {
						setTimeout(() => {
							blogDate.classList.add('animate');
						}, 200);
					}
				}, index * 150);
			}
		});
	}, { threshold: 0.2 });

	experienceSections.forEach(section => {
		experienceObserver.observe(section);
	});
}

// Timeline progression animation
function initTimelineAnimations() {
	const timelineItems = document.querySelectorAll('.timeline');

	const timelineObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 200);
			}
		});
	}, { threshold: 0.3 });

	timelineItems.forEach(item => {
		timelineObserver.observe(item);
	});
}

// Content stagger animation system
function initContentStagger() {
	const contentElements = document.querySelectorAll('.content-stagger');

	const contentObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 200);
			}
		});
	}, { threshold: 0.1 });

	contentElements.forEach(element => {
		contentObserver.observe(element);
	});
}

// Skills progression animation
function initSkillsAnimation() {
	const skillItems = document.querySelectorAll('.skill-progress');

	const skillsObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 100);
			}
		});
	}, { threshold: 0.5 });

	skillItems.forEach(item => {
		skillsObserver.observe(item);
	});
}

// Enhanced 3D hover effects for professional cards
function initProfessional3DEffects() {
	document.querySelectorAll('.professional-card').forEach(card => {
		card.addEventListener('mousemove', (e) => {
			const rect = card.getBoundingClientRect();
			const x = e.clientX - rect.left;
			const y = e.clientY - rect.top;
			const centerX = rect.width / 2;
			const centerY = rect.height / 2;
			const deltaX = (x - centerX) / 15;
			const deltaY = (y - centerY) / 15;

			card.style.transform = `
				perspective(1000px)
				rotateX(${deltaY}deg)
				rotateY(${deltaX}deg)
				translateZ(10px)
				scale(1.02)
			`;
		});

		card.addEventListener('mouseleave', () => {
			card.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) translateZ(0) scale(1)';
		});
	});
}

// Experience section hover effects
function initExperienceHoverEffects() {
	document.querySelectorAll('.experience-section').forEach(section => {
		section.addEventListener('mouseenter', function() {
			// Subtle glow effect
			this.style.boxShadow = '0 20px 40px rgba(255, 107, 107, 0.15)';

			// Animate icons
			const icon = this.querySelector('.fa');
			if (icon) {
				icon.style.transform = 'scale(1.2) rotate(10deg)';
				icon.style.textShadow = '0 0 10px rgba(255, 107, 107, 0.5)';
			}
		});

		section.addEventListener('mouseleave', function() {
			this.style.boxShadow = '';

			const icon = this.querySelector('.fa');
			if (icon) {
				icon.style.transform = 'scale(1) rotate(0deg)';
				icon.style.textShadow = '';
			}
		});
	});
}

// Tech tag ripple effect on click
function initTechTagEffects() {
	document.querySelectorAll('.tech-tag').forEach(tag => {
		tag.addEventListener('click', function(e) {
			// Create ripple effect
			const ripple = document.createElement('span');
			const rect = this.getBoundingClientRect();
			const size = Math.max(rect.width, rect.height);
			const x = e.clientX - rect.left - size / 2;
			const y = e.clientY - rect.top - size / 2;

			ripple.style.cssText = `
				position: absolute;
				border-radius: 50%;
				background: rgba(255, 255, 255, 0.6);
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

		// Enhanced hover effect
		tag.addEventListener('mouseenter', function() {
			this.style.transform = 'translateY(-3px) scale(1.05)';
			this.style.boxShadow = '0 8px 20px rgba(255, 107, 107, 0.4)';
		});

		tag.addEventListener('mouseleave', function() {
			this.style.transform = 'translateY(0) scale(1)';
			this.style.boxShadow = '';
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
	});
}

// Achievement list progressive reveal
function initAchievementAnimations() {
	document.querySelectorAll('.achievement-list').forEach(list => {
		const items = list.querySelectorAll('li');

		const listObserver = new IntersectionObserver((entries) => {
			entries.forEach(entry => {
				if (entry.isIntersecting) {
					const listItems = entry.target.querySelectorAll('li');
					listItems.forEach((item, index) => {
						setTimeout(() => {
							item.style.opacity = '1';
							item.style.transform = 'translateX(0)';
						}, index * 100);
					});
				}
			});
		}, { threshold: 0.3 });

		listObserver.observe(list);
	});
}

// Professional quote animation
function initQuoteAnimation() {
	const quotes = document.querySelectorAll('.professional-quote');

	const quoteObserver = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.style.opacity = '1';
				entry.target.style.transform = 'translateY(0) scale(1)';
			}
		});
	}, { threshold: 0.3 });

	quotes.forEach(quote => {
		quote.style.opacity = '0';
		quote.style.transform = 'translateY(30px) scale(0.95)';
		quote.style.transition = 'all 0.8s cubic-bezier(0.25, 0.46, 0.45, 0.94)';
		quoteObserver.observe(quote);
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

// Smooth page loading animation
function initPageLoadAnimation() {
	document.body.style.opacity = '0';
	document.body.style.transition = 'opacity 0.5s ease';

	setTimeout(() => {
		document.body.style.opacity = '1';
	}, 100);
}

// Initialize all animations when page loads
document.addEventListener('DOMContentLoaded', function() {
	initPageLoadAnimation();

	// Delay animation initialization for smooth loading
	setTimeout(() => {
		initScrollAnimations();
		initExperienceAnimations();
		initTimelineAnimations();
		initContentStagger();
		initSkillsAnimation();
		initProfessional3DEffects();
		initExperienceHoverEffects();
		initTechTagEffects();
		initParallaxEffect();
		initAchievementAnimations();
		initQuoteAnimation();
		initNavigationEffects();

		// Add loaded class for final touches
		document.body.classList.add('animations-loaded');
	}, 150);
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
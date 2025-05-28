// Typing effect implementation
const texts = [
    "DevOps Engineer",
    "Calisthenics Enthusiast",
    "Cloud Platform Specialist",
    "Automation Enthusiast"
];

let textIndex = 0;
let charIndex = 0;
let isDeleting = false;
let typeSpeed = 100;
let deleteSpeed = 50;
let pauseTime = 2000;

const typewriterElement = document.getElementById('typewriter-text');

function typeWriter() {
    const currentText = texts[textIndex];

    if (isDeleting) {
        typewriterElement.textContent = currentText.substring(0, charIndex - 1);
        charIndex--;

        if (charIndex === 0) {
            isDeleting = false;
            textIndex = (textIndex + 1) % texts.length;
            setTimeout(typeWriter, 500);
            return;
        }
        setTimeout(typeWriter, deleteSpeed);
    } else {
        typewriterElement.textContent = currentText.substring(0, charIndex + 1);
        charIndex++;

        if (charIndex === currentText.length) {
            setTimeout(() => {
                isDeleting = true;
                typeWriter();
            }, pauseTime);
            return;
        }
        setTimeout(typeWriter, typeSpeed);
    }
}

// SCROLL-TRIGGERED ANIMATIONS
function initScrollAnimations() {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('revealed');

                if (entry.target.querySelector('.progress-bar')) {
                    animateProgressBars(entry.target);
                }
            }
        });
    }, observerOptions);

    document.querySelectorAll('.scroll-reveal, .scroll-reveal-left, .scroll-reveal-right').forEach(el => {
        observer.observe(el);
    });

    document.querySelectorAll('#about .col-md-6:last-child').forEach(el => {
        observer.observe(el);
    });
}

// 📊 ANIMATED PROGRESS BARS 📊
function animateProgressBars(container) {
    const progressBars = container.querySelectorAll('.progress-bar');

    progressBars.forEach((bar, index) => {
        const targetWidth = bar.getAttribute('data-width');

        setTimeout(() => {
            bar.style.width = targetWidth + '%';
            bar.classList.add('animate');
        }, index * 200);
    });
}

// ENHANCED HOVER EFFECTS
function initEnhancedHoverEffects() {
    document.querySelectorAll('.portfolio-thumb').forEach(item => {
        item.addEventListener('mousemove', (e) => {
            const rect = item.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            const rotateX = (y - centerY) / 10;
            const rotateY = (centerX - x) / 10;

            item.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateZ(10px)`;
        });

        item.addEventListener('mouseleave', () => {
            item.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) translateZ(0)';
        });
    });

    document.querySelectorAll('.media').forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            const deltaX = (x - centerX) / 20;
            const deltaY = (y - centerY) / 20;

            card.style.transform = `translateX(${deltaX}px) translateY(${deltaY}px) rotateX(${deltaY}deg) rotateY(${deltaX}deg)`;
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = 'translateX(0) translateY(0) rotateX(0) rotateY(0)';
        });
    });
}

// STAGGERED ANIMATIONS
function initStaggeredAnimations() {
    const portfolioItems = document.querySelectorAll('.portfolio-thumb');

    const portfolioObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                setTimeout(() => {
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0) scale(1)';
                }, index * 150);
            }
        });
    }, { threshold: 0.1 });

    portfolioItems.forEach(item => {
        item.style.opacity = '0';
        item.style.transform = 'translateY(50px) scale(0.9)';
        item.style.transition = 'all 0.6s cubic-bezier(0.25, 0.46, 0.45, 0.94)';
        portfolioObserver.observe(item);
    });
}

// Enhanced scroll functionality that works with fullPage.js
document.addEventListener('DOMContentLoaded', function() {
    const scrollButtons = document.querySelectorAll('.smoothScroll, .slow-scroll');

    scrollButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();

            const targetHref = this.getAttribute('href');

            if (targetHref === '#portfolio') {
                setTimeout(() => {
                    if (window.$.fn.fullpage && window.$.fn.fullpage.moveTo) {
                        window.$.fn.fullpage.moveTo(4);
                    } else {
                        const targetElement = document.querySelector('#portfolio');
                        if (targetElement) {
                            targetElement.scrollIntoView({
                                behavior: 'smooth',
                                block: 'start'
                            });
                        }
                    }
                }, 100);
            }
        });
    });

    // Setup navigation tooltips and fix home button
    setTimeout(() => {
        const navItems = document.querySelectorAll('#fp-nav ul li a');
        const tooltips = ['Home', 'What I Do', 'About Me', 'Portfolio', 'Contact'];

        navItems.forEach((item, index) => {
            if (tooltips[index]) {
                item.setAttribute('data-tooltip', tooltips[index]);
            }

            item.addEventListener('click', function(e) {
                e.preventDefault();
                if (window.$.fn.fullpage && window.$.fn.fullpage.moveTo) {
                    // Special handling for Home button - scroll to absolute top
                    if (index === 0) {
                        window.$.fn.fullpage.moveTo(1);
                        // Additional scroll to absolute top for home
                        setTimeout(() => {
                            window.scrollTo({ top: 0, behavior: 'smooth' });
                        }, 100);
                    } else {
                        window.$.fn.fullpage.moveTo(index + 1);
                    }
                }
            });
        });
    }, 1000);
});

// INITIALIZE CLEAN ANIMATION SYSTEM
document.addEventListener('DOMContentLoaded', function() {
    // Start typing effect
    setTimeout(typeWriter, 1000);

    // Initialize essential animation systems
    initScrollAnimations();
    initEnhancedHoverEffects();
    initStaggeredAnimations();

    // Add loading complete class
    setTimeout(() => {
        document.body.classList.add('animations-loaded');
    }, 500);
});